import AppKit
import CoreGraphics
import CoreImage

public enum ImageUtilError: Error {
    case pngEncodingFailed
    case cgImageConversionFailed
}

public enum ImageUtil {
    public static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ImageUtilError.pngEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    public static func cgImage(from nsImage: NSImage) throws -> CGImage {
        var rect = CGRect(origin: .zero, size: nsImage.size)
        guard let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw ImageUtilError.cgImageConversionFailed
        }
        return cg
    }

    /// 从抠图下半部采样平均毛色,用于绘制与宠物配色一致的爪子。
    public static func averageFurColor(of image: CGImage) -> NSColor {
        let sampleSize = 32
        guard let context = CGContext(
            data: nil, width: sampleSize, height: sampleSize,
            bitsPerComponent: 8, bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .systemGray }
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        guard let data = context.data else { return .systemGray }
        let pixels = data.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)

        var r = 0.0, g = 0.0, b = 0.0, count = 0.0
        // CGContext 原点在左下,前一半行即图片下半部(宠物身体/爪子区域)。
        for y in 0..<(sampleSize / 2) {
            for x in 0..<sampleSize {
                let i = (y * sampleSize + x) * 4
                let alpha = Double(pixels[i + 3])
                guard alpha > 200 else { continue }
                r += Double(pixels[i])
                g += Double(pixels[i + 1])
                b += Double(pixels[i + 2])
                count += 1
            }
        }
        guard count > 0 else { return .systemGray }
        return NSColor(
            red: r / count / 255, green: g / count / 255, blue: b / count / 255, alpha: 1
        )
    }

    /// 以归一化中心点为圆心,从抠图中羽化裁出头部圆形区域。
    /// 边缘用径向渐变淡出,叠回身体上转动时看不出接缝。
    /// 返回头部图层位图与其在源图中的像素范围(左下角原点)。
    public static func featheredHeadCrop(
        from image: CGImage, normalizedCenter: CGPoint, radiusFraction: CGFloat
    ) -> (image: CGImage, pixelRect: CGRect)? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let center = CGPoint(x: normalizedCenter.x * width, y: normalizedCenter.y * height)
        let radius = max(radiusFraction * width, 24)

        let source = CIImage(cgImage: image)
        guard let gradientFilter = CIFilter(name: "CIRadialGradient") else { return nil }
        gradientFilter.setValue(CIVector(x: center.x, y: center.y), forKey: "inputCenter")
        gradientFilter.setValue(radius * 0.62, forKey: "inputRadius0")
        gradientFilter.setValue(radius, forKey: "inputRadius1")
        gradientFilter.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
        gradientFilter.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0), forKey: "inputColor1")
        guard let mask = gradientFilter.outputImage?.cropped(to: source.extent) else { return nil }

        guard let blend = CIFilter(name: "CIBlendWithAlphaMask") else { return nil }
        blend.setValue(source, forKey: kCIInputImageKey)
        blend.setValue(CIImage.empty().cropped(to: source.extent), forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        guard let output = blend.outputImage else { return nil }

        let cropRect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ).intersection(source.extent)
        guard !cropRect.isEmpty,
              let result = CIContext().createCGImage(output, from: cropRect)
        else { return nil }
        return (result, cropRect)
    }

    /// 把 emoji 渲染成位图,供 CALayer / CAEmitterCell 使用。
    public static func emojiImage(_ emoji: String, pointSize: CGFloat) -> CGImage? {
        let font = NSFont.systemFont(ofSize: pointSize)
        let string = NSAttributedString(string: emoji, attributes: [.font: font])
        let size = string.size()
        let image = NSImage(size: size)
        image.lockFocus()
        string.draw(at: .zero)
        image.unlockFocus()
        var rect = CGRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

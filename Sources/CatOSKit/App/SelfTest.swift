import AppKit
import Foundation

/// 命令行自测:跑完整处理管线并输出可人工检查的产物。
/// 用法:CatOS --selftest <照片路径> <输出目录> [--seed]
/// --seed 同时把结果写入宠物存档,下次正常启动直接出桌宠。
public enum SelfTest {
    public static func run(photoPath: String, outputPath: String, seed: Bool) -> Int32 {
        let photoURL = URL(fileURLWithPath: photoPath)
        let outDir = URL(fileURLWithPath: outputPath, isDirectory: true)

        guard let image = NSImage(contentsOf: photoURL),
              let source = try? ImageUtil.cgImage(from: image)
        else {
            FileHandle.standardError.write(Data("无法读取照片: \(photoPath)\n".utf8))
            return 1
        }

        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

            let cutout = try CutoutProcessor.cutout(from: source)
            try ImageUtil.writePNG(cutout, to: outDir.appendingPathComponent("cutout.png"))
            print("抠图完成: \(cutout.width)x\(cutout.height)")

            let eyes = PoseAnalyzer.detectEyes(in: cutout)
            let left = eyes.leftEye ?? CGPoint(x: 0.4, y: 0.65)
            let right = eyes.rightEye ?? CGPoint(x: 0.6, y: 0.65)
            print("眼睛检测: left=\(eyes.leftEye.map(String.init(describing:)) ?? "未检出(用默认)") "
                + "right=\(eyes.rightEye.map(String.init(describing:)) ?? "未检出(用默认)")")

            let preview = renderPreview(cutout: cutout, leftEye: left, rightEye: right)
            try ImageUtil.writePNG(preview, to: outDir.appendingPathComponent("preview.png"))
            print("预览图(含眼睛标记)已输出到 \(outDir.path)")

            if seed {
                let profile = PetProfile(name: "自测猫", leftEye: left, rightEye: right)
                try PetStore().save(profile: profile, image: cutout)
                print("已写入宠物存档,直接启动 CatOS 即可出桌宠")
            }
            return 0
        } catch {
            FileHandle.standardError.write(Data("自测失败: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    /// 棋盘格背景 + 抠图 + 眼睛圆圈标记,用于人工核对。
    private static func renderPreview(
        cutout: CGImage, leftEye: CGPoint, rightEye: CGPoint
    ) -> CGImage {
        let width = cutout.width
        let height = cutout.height
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        let tile = 24
        for y in stride(from: 0, to: height, by: tile) {
            for x in stride(from: 0, to: width, by: tile) {
                let isLight = ((x / tile) + (y / tile)) % 2 == 0
                context.setFillColor(gray: isLight ? 0.95 : 0.8, alpha: 1)
                context.fill(CGRect(x: x, y: y, width: tile, height: tile))
            }
        }
        context.draw(cutout, in: CGRect(x: 0, y: 0, width: width, height: height))

        let radius = CGFloat(width) * 0.04
        for (eye, color) in [(leftEye, CGColor(red: 0, green: 0.4, blue: 1, alpha: 1)),
                             (rightEye, CGColor(red: 1, green: 0.5, blue: 0, alpha: 1))] {
            let center = PetGeometry.denormalize(
                eye, in: CGSize(width: width, height: height)
            )
            context.setStrokeColor(color)
            context.setLineWidth(max(3, radius * 0.25))
            context.strokeEllipse(in: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
        }
        return context.makeImage()!
    }
}

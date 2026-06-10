import CoreImage
import Vision

public enum CutoutError: LocalizedError {
    case noSubject
    case renderFailed

    public var errorDescription: String? {
        switch self {
        case .noSubject: return "没有在照片里找到宠物主体,换一张更清晰的照片试试。"
        case .renderFailed: return "抠图渲染失败,请重试。"
        }
    }
}

/// 本地抠图:Vision 前景实例分割,输出透明背景、按主体裁剪的 CGImage。
public enum CutoutProcessor {
    public static func cutout(from source: CGImage) throws -> CGImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: source, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty
        else { throw CutoutError.noSubject }

        let buffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        guard let result = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw CutoutError.renderFailed
        }
        return result
    }
}

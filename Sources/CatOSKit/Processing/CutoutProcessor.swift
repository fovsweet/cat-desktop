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

        // 照片里有多个主体(如两只猫)时只保留最大的那个,
        // 避免把别的动物碎片一起抠进来。
        let buffer = try largestInstanceMask(observation: observation, handler: handler)
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        guard let result = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw CutoutError.renderFailed
        }
        return result
    }

    private static func largestInstanceMask(
        observation: VNInstanceMaskObservation, handler: VNImageRequestHandler
    ) throws -> CVPixelBuffer {
        let instances = observation.allInstances
        if instances.count <= 1 {
            return try observation.generateMaskedImage(
                ofInstances: instances, from: handler, croppedToInstancesExtent: true
            )
        }
        var best: (buffer: CVPixelBuffer, area: Int)?
        for index in instances {
            guard let buffer = try? observation.generateMaskedImage(
                ofInstances: IndexSet(integer: index),
                from: handler,
                croppedToInstancesExtent: true
            ) else { continue }
            let area = CVPixelBufferGetWidth(buffer) * CVPixelBufferGetHeight(buffer)
            if best == nil || area > best!.area {
                best = (buffer, area)
            }
        }
        guard let best else { throw CutoutError.noSubject }
        return best.buffer
    }
}

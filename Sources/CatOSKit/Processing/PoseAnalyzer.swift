import CoreGraphics
import Vision

public struct EyeDetection: Equatable {
    public var leftEye: CGPoint?
    public var rightEye: CGPoint?

    public init(leftEye: CGPoint? = nil, rightEye: CGPoint? = nil) {
        self.leftEye = leftEye
        self.rightEye = rightEye
    }
}

/// 猫狗身体姿态检测,定位双眼(归一化坐标,左下角原点)。
/// 检测失败不抛错——导入界面会降级为手动标记。
public enum PoseAnalyzer {
    private static let minimumConfidence: Float = 0.3

    public static func detectEyes(in image: CGImage) -> EyeDetection {
        let request = VNDetectAnimalBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first
        else { return EyeDetection() }

        func point(_ joint: VNAnimalBodyPoseObservation.JointName) -> CGPoint? {
            guard let recognized = try? observation.recognizedPoint(joint),
                  recognized.confidence >= minimumConfidence
            else { return nil }
            return recognized.location
        }
        return EyeDetection(leftEye: point(.leftEye), rightEye: point(.rightEye))
    }
}

import Foundation
import CoreGraphics

/// 宠物档案:抠图结果 + 眼睛位置(归一化坐标,左下角为原点)+ 展示参数。
public struct PetProfile: Codable, Equatable {
    public var id: UUID
    public var name: String
    public var imageFileName: String
    /// 归一化坐标(0...1),原点在图片左下角。
    public var leftEye: CGPoint
    public var rightEye: CGPoint
    /// 桌宠展示宽度(pt)。
    public var displayWidth: CGFloat

    public init(
        id: UUID = UUID(),
        name: String,
        imageFileName: String = "cutout.png",
        leftEye: CGPoint,
        rightEye: CGPoint,
        displayWidth: CGFloat = 220
    ) {
        self.id = id
        self.name = name
        self.imageFileName = imageFileName
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.displayWidth = displayWidth
    }
}

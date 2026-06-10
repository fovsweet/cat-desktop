import CoreGraphics
import Foundation

/// 纯几何计算:瞳孔跟随、身体倾斜、坐标换算。无 AppKit 依赖,可单测。
public enum PetGeometry {
    /// 瞳孔相对眼球中心的偏移:朝目标方向、最多 maxOffset。
    public static func pupilOffset(
        eyeCenter: CGPoint, target: CGPoint, maxOffset: CGFloat
    ) -> CGPoint {
        let dx = target.x - eyeCenter.x
        let dy = target.y - eyeCenter.y
        let distance = hypot(dx, dy)
        guard distance > 0.001 else { return .zero }
        // 距离越近瞳孔位移越小,模拟对焦;120pt 以外达到最大偏移。
        let magnitude = maxOffset * min(distance / 120, 1)
        return CGPoint(x: dx / distance * magnitude, y: dy / distance * magnitude)
    }

    /// 身体朝鼠标方向轻微倾斜的角度(弧度)。目标在右侧时逆时针为负。
    public static func leanAngle(
        petCenterX: CGFloat, targetX: CGFloat, maxDegrees: CGFloat = 6
    ) -> CGFloat {
        let dx = targetX - petCenterX
        let normalized = max(-1, min(1, dx / 500))
        return -normalized * maxDegrees * .pi / 180
    }

    /// 归一化坐标(左下角原点)→ 视图坐标。
    public static func denormalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    /// 视图坐标 → 归一化坐标,夹取到 0...1。
    public static func normalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(
            x: max(0, min(1, point.x / size.width)),
            y: max(0, min(1, point.y / size.height))
        )
    }

    /// 伸爪动作:从锚点指向目标的角度与长度(长度封顶)。
    public static func pawStrike(
        from anchor: CGPoint, to target: CGPoint, maxLength: CGFloat
    ) -> (angle: CGFloat, length: CGFloat) {
        let dx = target.x - anchor.x
        let dy = target.y - anchor.y
        return (atan2(dy, dx), min(hypot(dx, dy), maxLength))
    }
}

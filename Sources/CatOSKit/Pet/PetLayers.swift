import AppKit
import QuartzCore

/// 卡通眼睛:白色眼球 + 跟随鼠标的瞳孔 + 高光。
public final class EyeLayer: CALayer {
    private let sclera = CAShapeLayer()
    private let pupil = CAShapeLayer()
    private let highlight = CAShapeLayer()
    private let eyeRadius: CGFloat

    public init(radius: CGFloat) {
        self.eyeRadius = radius
        super.init()
        bounds = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)

        sclera.path = CGPath(ellipseIn: bounds, transform: nil)
        sclera.fillColor = NSColor.white.cgColor
        sclera.strokeColor = NSColor.black.withAlphaComponent(0.55).cgColor
        sclera.lineWidth = max(1, radius * 0.12)
        addSublayer(sclera)

        let pupilRadius = radius * 0.48
        pupil.path = CGPath(
            ellipseIn: CGRect(x: -pupilRadius, y: -pupilRadius,
                              width: pupilRadius * 2, height: pupilRadius * 2),
            transform: nil
        )
        pupil.fillColor = NSColor.black.cgColor
        addSublayer(pupil)

        let hlRadius = radius * 0.14
        highlight.path = CGPath(
            ellipseIn: CGRect(x: -hlRadius, y: -hlRadius,
                              width: hlRadius * 2, height: hlRadius * 2),
            transform: nil
        )
        highlight.fillColor = NSColor.white.withAlphaComponent(0.9).cgColor
        highlight.position = CGPoint(x: radius * 0.2, y: radius * 0.2)
        pupil.addSublayer(highlight)
    }

    override init(layer: Any) {
        self.eyeRadius = (layer as? EyeLayer)?.eyeRadius ?? 10
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    public var maxPupilOffset: CGFloat { eyeRadius * 0.4 }

    public func setPupilOffset(_ offset: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pupil.position = offset
        CATransaction.commit()
    }

    public func blink() {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale.y")
        animation.values = [1, 0.08, 1]
        animation.keyTimes = [0, 0.5, 1]
        animation.duration = 0.18
        add(animation, forKey: "blink")
    }

    public func setClosed(_ closed: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        transform = closed ? CATransform3DMakeScale(1, 0.08, 1) : CATransform3DIdentity
        CATransaction.commit()
    }
}

/// 程序化绘制的爪子(配色取自宠物毛色),从身体伸向点击位置。
public final class PawLayer: CAShapeLayer {
    private let armHeight: CGFloat

    public init(furColor: NSColor, armHeight: CGFloat = 26) {
        self.armHeight = armHeight
        super.init()
        fillColor = furColor.cgColor
        strokeColor = furColor.shadow(withLevel: 0.3)?.cgColor
        lineWidth = 1.5
        anchorPoint = CGPoint(x: 0, y: 0.5)
        isHidden = true
    }

    override init(layer: Any) {
        self.armHeight = (layer as? PawLayer)?.armHeight ?? 26
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    /// 朝 angle 方向伸出 length,停留片刻后收回。
    public func strike(angle: CGFloat, length: CGFloat, duration: TimeInterval) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        path = Self.pawPath(length: length, height: armHeight)
        bounds = CGRect(x: 0, y: -armHeight, width: length + armHeight, height: armHeight * 2)
        setAffineTransform(CGAffineTransform(rotationAngle: angle))
        isHidden = false
        CATransaction.commit()

        let extend = CAKeyframeAnimation(keyPath: "transform.scale.x")
        extend.values = [0.1, 1.05, 1, 1, 0.1]
        extend.keyTimes = [0, 0.3, 0.4, 0.7, 1]
        extend.duration = duration
        extend.isRemovedOnCompletion = true
        add(extend, forKey: "strike")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isHidden = true
        }
    }

    /// 手臂胶囊 + 掌部圆 + 三个脚趾。
    private static func pawPath(length: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let armRect = CGRect(x: 0, y: -height / 2, width: length, height: height)
        path.addRoundedRect(in: armRect, cornerWidth: height / 2, cornerHeight: height / 2)

        let palmRadius = height * 0.75
        path.addEllipse(in: CGRect(
            x: length - palmRadius, y: -palmRadius,
            width: palmRadius * 2, height: palmRadius * 2
        ))
        let toeRadius = height * 0.28
        for i in 0..<3 {
            let toeAngle = CGFloat(i - 1) * 0.55
            let cx = length + palmRadius * 0.95 * cos(toeAngle)
            let cy = palmRadius * 1.05 * sin(toeAngle)
            path.addEllipse(in: CGRect(
                x: cx - toeRadius, y: cy - toeRadius,
                width: toeRadius * 2, height: toeRadius * 2
            ))
        }
        return path
    }
}

public enum PetLayerFactory {
    /// 爱心粒子发射器(默认不发射,burst 时喷一波)。
    public static func makeHeartEmitter() -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .point
        emitter.birthRate = 0

        let cell = CAEmitterCell()
        cell.contents = ImageUtil.emojiImage("❤️", pointSize: 18)
        cell.birthRate = 14
        cell.lifetime = 1.4
        cell.velocity = 70
        cell.velocityRange = 30
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 3
        cell.yAcceleration = 40
        cell.scale = 0.7
        cell.scaleRange = 0.3
        cell.alphaSpeed = -0.8
        cell.spin = 1.2
        cell.spinRange = 1
        emitter.emitterCells = [cell]
        return emitter
    }

    public static func burst(_ emitter: CAEmitterLayer, duration: TimeInterval = 0.6) {
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            emitter.birthRate = 0
        }
    }

    /// emoji 文字层(食物 / 💤)。
    public static func makeEmojiLayer(_ emoji: String, fontSize: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = emoji
        layer.fontSize = fontSize
        layer.alignmentMode = .center
        layer.bounds = CGRect(x: 0, y: 0, width: fontSize * 1.4, height: fontSize * 1.4)
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        return layer
    }
}

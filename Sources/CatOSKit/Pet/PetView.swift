import AppKit
import QuartzCore

/// 桌宠视图:2.5D 木偶 —— 身体(抠图)+ 眼睛 + 爪子 + 食物/爱心/Zzz 图层。
public final class PetView: NSView {
    public var onClick: ((_ viewPoint: CGPoint, _ screenPoint: CGPoint) -> Void)?
    public var contextMenuProvider: (() -> NSMenu)?

    private let container = CALayer()
    private let body = CALayer()
    private let leftEye: EyeLayer
    private let rightEye: EyeLayer
    private let paw: PawLayer
    private let hearts = PetLayerFactory.makeHeartEmitter()
    private let zzz = PetLayerFactory.makeEmojiLayer("💤", fontSize: 22)
    private var foodLayer: CATextLayer?

    private let petRect: CGRect
    /// 爪子伸出可超出宠物本体,四周留白。
    private static let padding: CGFloat = 70

    private var dragStartLocation: NSPoint?
    private var dragStartOrigin: NSPoint?
    private var didDrag = false

    // MARK: - 初始化

    public init(profile: PetProfile, image: NSImage) {
        let cgImage = try? ImageUtil.cgImage(from: image)
        let aspect = image.size.width > 0 ? image.size.height / image.size.width : 1
        let petSize = CGSize(width: profile.displayWidth,
                             height: profile.displayWidth * aspect)
        petRect = CGRect(x: Self.padding, y: 12, width: petSize.width, height: petSize.height)
        let viewSize = CGSize(width: petSize.width + Self.padding * 2,
                              height: petSize.height + Self.padding + 12)

        let eyeRadius = min(max(petSize.width * 0.055, 7), 18)
        leftEye = EyeLayer(radius: eyeRadius)
        rightEye = EyeLayer(radius: eyeRadius)

        let furColor = cgImage.map(ImageUtil.averageFurColor) ?? .systemGray
        paw = PawLayer(furColor: furColor)

        super.init(frame: CGRect(origin: .zero, size: viewSize))
        wantsLayer = true

        container.frame = bounds
        container.anchorPoint = CGPoint(x: 0.5, y: 0)
        container.position = CGPoint(x: viewSize.width / 2, y: 0)
        layer?.addSublayer(container)

        body.contents = cgImage
        body.frame = petRect
        body.contentsGravity = .resizeAspect
        body.shadowColor = NSColor.black.cgColor
        body.shadowOpacity = 0.25
        body.shadowOffset = CGSize(width: 0, height: -3)
        body.shadowRadius = 6
        container.addSublayer(body)

        leftEye.position = eyePosition(profile.leftEye)
        rightEye.position = eyePosition(profile.rightEye)
        container.addSublayer(leftEye)
        container.addSublayer(rightEye)

        paw.position = CGPoint(x: petRect.midX, y: petRect.minY + petRect.height * 0.28)
        container.addSublayer(paw)

        hearts.emitterPosition = CGPoint(x: petRect.midX, y: petRect.midY + petRect.height * 0.3)
        layer?.addSublayer(hearts)

        zzz.position = CGPoint(x: petRect.midX + petRect.width * 0.3,
                               y: petRect.maxY + 18)
        zzz.isHidden = true
        layer?.addSublayer(zzz)

        startBreathing()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func eyePosition(_ normalized: CGPoint) -> CGPoint {
        let p = PetGeometry.denormalize(normalized, in: petRect.size)
        return CGPoint(x: petRect.minX + p.x, y: petRect.minY + p.y)
    }

    private func startBreathing() {
        let breathe = CABasicAnimation(keyPath: "transform.scale.y")
        breathe.fromValue = 1
        breathe.toValue = 1.015
        breathe.duration = 1.6
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        body.add(breathe, forKey: "breathe")
    }

    // MARK: - 动作渲染

    public func updateGaze(towardScreenPoint point: CGPoint) {
        guard let window else { return }
        for eye in [leftEye, rightEye] {
            let inWindow = convert(eye.position, to: nil)
            let onScreen = window.convertPoint(toScreen: inWindow)
            let offset = PetGeometry.pupilOffset(
                eyeCenter: onScreen, target: point, maxOffset: eye.maxPupilOffset
            )
            eye.setPupilOffset(offset)
        }
        let centerInWindow = convert(CGPoint(x: petRect.midX, y: petRect.midY), to: nil)
        let centerOnScreen = window.convertPoint(toScreen: centerInWindow)
        let lean = PetGeometry.leanAngle(petCenterX: centerOnScreen.x, targetX: point.x)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        container.setAffineTransform(CGAffineTransform(rotationAngle: lean))
        CATransaction.commit()
    }

    public func performBlink() {
        leftEye.blink()
        rightEye.blink()
    }

    public func performPaw(towardViewPoint point: CGPoint) {
        let strike = PetGeometry.pawStrike(
            from: paw.position, to: point, maxLength: petRect.width * 0.7
        )
        paw.strike(angle: strike.angle, length: strike.length, duration: 0.65)
    }

    /// 扑到位后落地动作:拍一下 + 爱心。
    public func performPounceLanding() {
        performPaw(towardViewPoint: CGPoint(x: petRect.midX, y: petRect.minY + 8))
        PetLayerFactory.burst(hearts, duration: 0.4)
    }

    public func performEat(_ food: FoodKind) {
        foodLayer?.removeFromSuperlayer()
        let layer = PetLayerFactory.makeEmojiLayer(food.emoji, fontSize: 30)
        let foodX = petRect.midX + petRect.width * 0.32
        layer.position = CGPoint(x: foodX, y: bounds.height - 10)
        self.layer?.addSublayer(layer)
        foodLayer = layer

        // 1. 食物落地
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.45)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        layer.position = CGPoint(x: foodX, y: petRect.minY + 16)
        CATransaction.commit()

        // 2. 低头啃食(朝食物方向反复俯身)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let bob = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            bob.values = [0, -0.14, -0.02, -0.14, -0.02, -0.14, 0]
            bob.duration = 1.5
            self.container.add(bob, forKey: "eatBob")
        }
        // 3. 食物被吃掉,冒爱心
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { [weak self] in
            guard let self, let layer = self.foodLayer else { return }
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            layer.transform = CATransform3DMakeScale(0.01, 0.01, 1)
            layer.opacity = 0
            CATransaction.commit()
            PetLayerFactory.burst(self.hearts, duration: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.foodLayer?.removeFromSuperlayer()
            self?.foodLayer = nil
        }
    }

    public func performLove() {
        let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wiggle.values = [0, 0.09, -0.09, 0.07, -0.07, 0]
        wiggle.duration = 1.2
        container.add(wiggle, forKey: "wiggle")
        PetLayerFactory.burst(hearts, duration: 0.9)
    }

    public func setSleeping(_ sleeping: Bool) {
        leftEye.setClosed(sleeping)
        rightEye.setClosed(sleeping)
        zzz.isHidden = !sleeping
        if sleeping {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.4)
            container.setAffineTransform(.identity)
            CATransaction.commit()
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.25
            pulse.toValue = 1
            pulse.duration = 1.2
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            zzz.add(pulse, forKey: "pulse")
        } else {
            zzz.removeAllAnimations()
        }
    }

    // MARK: - 鼠标事件(拖动 vs 点击)

    public override func mouseDown(with event: NSEvent) {
        dragStartLocation = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin
        didDrag = false
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartLocation, let origin = dragStartOrigin,
              let window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - start.x
        let dy = current.y - start.y
        if abs(dx) > 4 || abs(dy) > 4 { didDrag = true }
        window.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    public override func mouseUp(with event: NSEvent) {
        defer {
            dragStartLocation = nil
            dragStartOrigin = nil
        }
        guard !didDrag else { return }
        let viewPoint = convert(event.locationInWindow, from: nil)
        onClick?(viewPoint, NSEvent.mouseLocation)
    }

    public override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

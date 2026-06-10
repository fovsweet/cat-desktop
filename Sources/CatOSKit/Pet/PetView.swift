import AppKit
import QuartzCore

/// 桌宠视图:2.5D 木偶 —— 身体(抠图)+ 可转动的头部图层 + 爪子 + 食物/爱心/Zzz。
/// 头部从抠图中以双眼为中心羽化裁出,绕颈部支点转向鼠标方向。
public final class PetView: NSView {
    public var onClick: ((_ viewPoint: CGPoint, _ screenPoint: CGPoint) -> Void)?
    public var contextMenuProvider: (() -> NSMenu)?

    private let container = CALayer()
    private let body = CALayer()
    private let head = CALayer()
    private let paw: PawLayer
    private let hearts = PetLayerFactory.makeHeartEmitter()
    private let zzz = PetLayerFactory.makeEmojiLayer("💤", fontSize: 22)
    private var foodLayer: CATextLayer?

    private let petRect: CGRect
    private var headCenterInView: CGPoint
    private var isSleeping = false
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

        let furColor = cgImage.map(ImageUtil.averageFurColor) ?? .systemGray
        paw = PawLayer(furColor: furColor)
        headCenterInView = CGPoint(x: petRect.midX, y: petRect.maxY * 0.8)

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

        setupHead(profile: profile, cgImage: cgImage)

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

    /// 以双眼中点为头部中心,羽化裁出头部并叠在身体上方。
    private func setupHead(profile: PetProfile, cgImage: CGImage?) {
        guard let cgImage else { return }
        let eyeMid = CGPoint(
            x: (profile.leftEye.x + profile.rightEye.x) / 2,
            y: (profile.leftEye.y + profile.rightEye.y) / 2
        )
        let eyeDistance = hypot(
            profile.leftEye.x - profile.rightEye.x,
            (profile.leftEye.y - profile.rightEye.y)
                * (CGFloat(cgImage.height) / CGFloat(cgImage.width))
        )
        // 头部半径:双眼距的 2.1 倍,至少占图宽 16%
        let radiusFraction = max(eyeDistance * 2.1, 0.16)

        guard let crop = ImageUtil.featheredHeadCrop(
            from: cgImage, normalizedCenter: eyeMid, radiusFraction: radiusFraction
        ) else { return }

        let scale = petRect.width / CGFloat(cgImage.width)
        let frame = CGRect(
            x: petRect.minX + crop.pixelRect.minX * scale,
            y: petRect.minY + crop.pixelRect.minY * scale,
            width: crop.pixelRect.width * scale,
            height: crop.pixelRect.height * scale
        )
        head.contents = crop.image
        head.frame = frame
        // 支点放在头部下缘(颈部),转头绕颈转
        head.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        head.position = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.12)
        headCenterInView = CGPoint(x: frame.midX, y: frame.midY)
        container.addSublayer(head)
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

    /// 头跟着鼠标转:水平转头 + 垂直微抬/低头,身体轻微倾斜。
    public func updateGaze(towardScreenPoint point: CGPoint) {
        guard let window, !isSleeping else { return }
        let headOnScreen = window.convertPoint(
            toScreen: convert(headCenterInView, to: nil)
        )
        let turn = PetGeometry.headTurnAngle(headCenterX: headOnScreen.x, targetX: point.x)
        let lift = PetGeometry.headLift(headCenterY: headOnScreen.y, targetY: point.y)
        let lean = PetGeometry.leanAngle(
            petCenterX: headOnScreen.x, targetX: point.x, maxDegrees: 3
        )

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        head.setAffineTransform(
            CGAffineTransform(translationX: 0, y: lift).rotated(by: turn)
        )
        container.setAffineTransform(CGAffineTransform(rotationAngle: lean))
        CATransaction.commit()
    }

    /// 醒着时的小动作:轻轻点一下头(代替原来的眨眼)。
    public func performBlink() {
        guard !isSleeping else { return }
        let nod = CAKeyframeAnimation(keyPath: "transform.translation.y")
        nod.values = [0, -3, 0]
        nod.duration = 0.3
        nod.isAdditive = true
        head.add(nod, forKey: "nod")
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

        // 2. 低头啃食:头朝食物方向反复俯身
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let bob = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            bob.values = [0, -0.3, -0.06, -0.3, -0.06, -0.3, 0]
            bob.duration = 1.5
            bob.isAdditive = true
            self.head.add(bob, forKey: "eatBob")
            let bodyBob = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            bodyBob.values = [0, -0.08, 0, -0.08, 0]
            bodyBob.duration = 1.5
            bodyBob.isAdditive = true
            self.container.add(bodyBob, forKey: "eatBob")
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
        wiggle.isAdditive = true
        container.add(wiggle, forKey: "wiggle")
        PetLayerFactory.burst(hearts, duration: 0.9)
    }

    /// 睡觉:头垂下来 + Zzz;醒来复位。
    public func setSleeping(_ sleeping: Bool) {
        isSleeping = sleeping
        zzz.isHidden = !sleeping
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        if sleeping {
            head.setAffineTransform(
                CGAffineTransform(translationX: 0, y: -6).rotated(by: -0.16)
            )
            container.setAffineTransform(.identity)
        } else {
            head.setAffineTransform(.identity)
        }
        CATransaction.commit()

        if sleeping {
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

    /// 步行循环:身体左右摇摆 + 上下颠簸,模拟迈步。
    public func setWalking(_ walking: Bool) {
        if walking {
            let rock = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            rock.values = [0, 0.045, 0, -0.045, 0]
            rock.duration = 0.55
            rock.repeatCount = .infinity
            rock.isAdditive = true
            container.add(rock, forKey: "walkRock")

            let bob = CAKeyframeAnimation(keyPath: "position.y")
            bob.values = [0, 5, 0, 5, 0]
            bob.duration = 0.55
            bob.repeatCount = .infinity
            bob.isAdditive = true
            container.add(bob, forKey: "walkBob")
        } else {
            container.removeAnimation(forKey: "walkRock")
            container.removeAnimation(forKey: "walkBob")
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

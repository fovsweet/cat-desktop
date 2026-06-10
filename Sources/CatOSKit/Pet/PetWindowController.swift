import AppKit

/// 透明置顶桌宠窗口;实现 PetActing,把动作转发给视图,
/// 自己负责"扑捉鼠标"的窗口位移动画。
public final class PetWindowController: NSWindowController, PetActing {
    public var onFeed: ((FoodKind) -> Void)?
    public var onPetting: (() -> Void)?
    public var onChangePet: (() -> Void)?
    public var onQuit: (() -> Void)?
    /// 走到鼠标附近后通知行为引擎。
    public var onWalkArrived: (() -> Void)?

    private let petView: PetView
    private let petName: String

    /// 定时器逐帧移动窗口。不用 window.animator():它会把新旧窗口
    /// 快照交叉淡化,产生"图片重叠"残影。
    private var moveTimer: Timer?
    private var moveTarget: CGPoint = .zero
    private var moveSpeed: CGFloat = 0
    private var moveArriveDistance: CGFloat = 0
    private var onMoveArrived: (() -> Void)?
    private static let moveTickInterval: TimeInterval = 1.0 / 60.0

    public init(profile: PetProfile, image: NSImage) {
        petView = PetView(profile: profile, image: image)
        petName = profile.name

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: petView.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.contentView = petView

        super.init(window: panel)

        petView.contextMenuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        placeAtBottomRight()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    public var petViewForWiring: PetView { petView }

    private func placeAtBottomRight() {
        guard let screen = NSScreen.main, let window else { return }
        let visible = screen.visibleFrame
        window.setFrameOrigin(NSPoint(
            x: visible.maxX - window.frame.width - 40,
            y: visible.minY + 20
        ))
    }

    // MARK: - PetActing

    public func updateGaze(towardScreenPoint point: CGPoint) {
        petView.updateGaze(towardScreenPoint: point)
    }

    public func performBlink() { petView.performBlink() }

    public func performPaw(towardViewPoint point: CGPoint) {
        petView.performPaw(towardViewPoint: point)
    }

    /// 整只宠物跳向鼠标位置(捕捉!),落地后拍一下 + 爱心。
    public func performPounce(towardScreenPoint point: CGPoint) {
        startMoving(toward: point, speed: 1100, arriveWithin: 10) { [weak self] in
            self?.petView.performPounceLanding()
        }
    }

    public func performEat(_ food: FoodKind) { petView.performEat(food) }

    public func performLove() { petView.performLove() }

    public func setSleeping(_ sleeping: Bool) { petView.setSleeping(sleeping) }

    public func startWalk(towardScreenPoint point: CGPoint) {
        petView.setWalking(true)
        startMoving(toward: point, speed: 170, arriveWithin: 150) { [weak self] in
            self?.petView.setWalking(false)
            self?.onWalkArrived?()
        }
    }

    public func updateWalkTarget(_ point: CGPoint) {
        moveTarget = point
    }

    public func stopWalk() {
        stopMoving()
        petView.setWalking(false)
    }

    // MARK: - 窗口移动器

    /// target 为期望的宠物中心点(屏幕坐标,左下原点)。
    private func startMoving(
        toward target: CGPoint, speed: CGFloat, arriveWithin: CGFloat,
        onArrive: @escaping () -> Void
    ) {
        stopMoving()
        moveTarget = target
        moveSpeed = speed
        moveArriveDistance = arriveWithin
        onMoveArrived = onArrive
        let timer = Timer(timeInterval: Self.moveTickInterval, repeats: true) { [weak self] _ in
            self?.moveTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        moveTimer = timer
    }

    private func stopMoving() {
        moveTimer?.invalidate()
        moveTimer = nil
        onMoveArrived = nil
    }

    private func moveTick() {
        guard let window else {
            stopMoving()
            return
        }
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let distance = hypot(moveTarget.x - center.x, moveTarget.y - center.y)
        if distance <= moveArriveDistance {
            let arrived = onMoveArrived
            stopMoving()
            arrived?()
            return
        }
        let step = PetGeometry.stepToward(
            origin: center, target: moveTarget,
            maxStep: moveSpeed * Self.moveTickInterval
        )
        var origin = CGPoint(
            x: step.position.x - window.frame.width / 2,
            y: step.position.y - window.frame.height / 2
        )
        if let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            origin.x = max(visible.minX - 40,
                           min(origin.x, visible.maxX - window.frame.width + 40))
            origin.y = max(visible.minY - 10,
                           min(origin.y, visible.maxY - window.frame.height))
        }
        // 被屏幕边缘夹住走不动时视为到达,避免定时器空转
        if abs(origin.x - window.frame.origin.x) < 0.1,
           abs(origin.y - window.frame.origin.y) < 0.1 {
            let arrived = onMoveArrived
            stopMoving()
            arrived?()
            return
        }
        window.setFrameOrigin(origin)
    }

    // MARK: - 右键菜单

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let title = NSMenuItem(title: "🐾 \(petName)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let feedItem = NSMenuItem(title: "投喂", action: nil, keyEquivalent: "")
        let feedMenu = NSMenu()
        for food in FoodKind.allCases {
            let item = NSMenuItem(
                title: "\(food.emoji) \(food.displayName)",
                action: #selector(feedAction(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = food.rawValue
            feedMenu.addItem(item)
        }
        feedItem.submenu = feedMenu
        menu.addItem(feedItem)

        let petItem = NSMenuItem(title: "抚摸 ❤️", action: #selector(pettingAction), keyEquivalent: "")
        petItem.target = self
        menu.addItem(petItem)

        menu.addItem(.separator())

        let change = NSMenuItem(title: "更换宠物照片…", action: #selector(changePetAction), keyEquivalent: "")
        change.target = self
        menu.addItem(change)

        let hide = NSMenuItem(title: "隐藏宠物", action: #selector(hideAction), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        let quit = NSMenuItem(title: "退出 CatOS", action: #selector(quitAction), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func feedAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let food = FoodKind(rawValue: raw) else { return }
        onFeed?(food)
    }

    @objc private func pettingAction() { onPetting?() }
    @objc private func changePetAction() { onChangePet?() }
    @objc private func hideAction() { window?.orderOut(nil) }
    @objc private func quitAction() { onQuit?() }
}

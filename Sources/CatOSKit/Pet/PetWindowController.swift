import AppKit

/// 透明置顶桌宠窗口;实现 PetActing,把动作转发给视图,
/// 自己负责"扑捉鼠标"的窗口位移动画。
public final class PetWindowController: NSWindowController, PetActing {
    public var onFeed: ((FoodKind) -> Void)?
    public var onPetting: (() -> Void)?
    public var onChangePet: (() -> Void)?
    public var onQuit: (() -> Void)?

    private let petView: PetView
    private let petName: String

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
        guard let window else { return }
        var target = NSPoint(
            x: point.x - window.frame.width / 2,
            y: point.y - window.frame.height * 0.25
        )
        if let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            target.x = max(visible.minX - 40, min(target.x, visible.maxX - window.frame.width + 40))
            target.y = max(visible.minY - 10, min(target.y, visible.maxY - window.frame.height))
        }
        let frame = NSRect(origin: target, size: window.frame.size)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(frame, display: true)
        }, completionHandler: { [weak self] in
            self?.petView.performPounceLanding()
        })
    }

    public func performEat(_ food: FoodKind) { petView.performEat(food) }

    public func performLove() { petView.performLove() }

    public func setSleeping(_ sleeping: Bool) { petView.setSleeping(sleeping) }

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

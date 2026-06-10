import AppKit
import SwiftUI

/// 导入窗口:拖照片 → 抠图 → 标眼睛 → 上桌面。
public final class OnboardingWindowController: NSWindowController {
    private let model = OnboardingModel()

    public init(onComplete: @escaping (PetProfile, CGImage) -> Void) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CatOS — 创建桌宠"
        super.init(window: window)

        model.onComplete = onComplete
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(model: model)
        )
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    public func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

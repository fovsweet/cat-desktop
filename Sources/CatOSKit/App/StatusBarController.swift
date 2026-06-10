import AppKit

/// 菜单栏 🐾 入口:显示宠物、更换照片、退出。
public final class StatusBarController {
    private let statusItem: NSStatusItem
    private let onShowPet: () -> Void
    private let onChangePet: () -> Void

    public init(onShowPet: @escaping () -> Void, onChangePet: @escaping () -> Void) {
        self.onShowPet = onShowPet
        self.onChangePet = onChangePet

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "🐾"

        let menu = NSMenu()
        let show = NSMenuItem(title: "显示宠物", action: #selector(showPet), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let change = NSMenuItem(title: "更换宠物照片…", action: #selector(changePet), keyEquivalent: "")
        change.target = self
        menu.addItem(change)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 CatOS", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func showPet() { onShowPet() }
    @objc private func changePet() { onChangePet() }
    @objc private func quit() { NSApp.terminate(nil) }
}

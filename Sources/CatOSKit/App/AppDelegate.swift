import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PetStore()
    private var statusBar: StatusBarController?
    private var onboarding: OnboardingWindowController?
    private var petController: PetWindowController?
    private var engine: BehaviorEngine?
    private var tracker: MouseTracker?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        statusBar = StatusBarController(
            onShowPet: { [weak self] in
                self?.petController?.window?.orderFrontRegardless()
            },
            onChangePet: { [weak self] in self?.showOnboarding() }
        )

        if let saved = store.loadCurrent() {
            spawnPet(profile: saved.profile, image: saved.image)
        } else {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        if let onboarding {
            onboarding.present()
            return
        }
        let controller = OnboardingWindowController { [weak self] profile, cutout in
            self?.completeOnboarding(profile: profile, cutout: cutout)
        }
        onboarding = controller
        controller.present()
    }

    private func completeOnboarding(profile: PetProfile, cutout: CGImage) {
        do {
            try store.save(profile: profile, image: cutout)
        } catch {
            presentError(error)
            return
        }
        onboarding?.close()
        onboarding = nil
        teardownPet()
        let image = NSImage(
            cgImage: cutout,
            size: NSSize(width: cutout.width, height: cutout.height)
        )
        spawnPet(profile: profile, image: image)
    }

    private func spawnPet(profile: PetProfile, image: NSImage) {
        let controller = PetWindowController(profile: profile, image: image)
        let engine = BehaviorEngine()
        engine.actor = controller
        engine.petFrameProvider = { [weak controller] in
            controller?.window?.frame ?? .zero
        }

        controller.petViewForWiring.onClick = { [weak engine] viewPoint, screenPoint in
            engine?.handleClick(atViewPoint: viewPoint, screenPoint: screenPoint)
        }
        controller.onFeed = { [weak engine] food in engine?.feed(food) }
        controller.onPetting = { [weak engine] in engine?.petting() }
        controller.onChangePet = { [weak self] in self?.showOnboarding() }
        controller.onQuit = { NSApp.terminate(nil) }
        controller.onWalkArrived = { [weak engine] in engine?.walkArrived() }

        controller.window?.orderFrontRegardless()

        let tracker = MouseTracker(
            onMove: { [weak engine] point in
                engine?.handleMouseMoved(toScreenPoint: point)
            },
            onTick: { [weak engine] in engine?.tick() }
        )
        tracker.start()

        self.petController = controller
        self.engine = engine
        self.tracker = tracker

        DemoDirector.runIfRequested(engine: engine, window: controller.window)
    }

    private func teardownPet() {
        tracker?.stop()
        tracker = nil
        engine = nil
        petController?.close()
        petController = nil
    }

    /// 防止多个实例同时跑出两只重叠的宠物:新实例启动时结束旧实例。
    private func terminateOtherInstances() {
        let currentPID = NSRunningApplication.current.processIdentifier
        for app in NSWorkspace.shared.runningApplications
        where app.processIdentifier != currentPID
            && (app.bundleIdentifier == "com.fov.catos" || app.localizedName == "CatOS") {
            app.forceTerminate()
        }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "保存宠物失败"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

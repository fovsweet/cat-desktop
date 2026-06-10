import AppKit

/// 全局鼠标位置轮询(NSEvent.mouseLocation 无需辅助功能权限)。
public final class MouseTracker {
    private var timer: Timer?
    private var lastLocation: CGPoint = .zero
    private let onMove: (CGPoint) -> Void
    private let onTick: () -> Void

    public init(onMove: @escaping (CGPoint) -> Void, onTick: @escaping () -> Void) {
        self.onMove = onMove
        self.onTick = onTick
    }

    public func start() {
        stop()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.onTick()
            let location = NSEvent.mouseLocation
            guard location != self.lastLocation else { return }
            self.lastLocation = location
            self.onMove(location)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stop() }
}

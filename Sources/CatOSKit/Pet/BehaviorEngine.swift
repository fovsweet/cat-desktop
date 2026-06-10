import CoreGraphics
import Foundation

public enum FoodKind: String, CaseIterable {
    case fish, chicken, milk

    public var emoji: String {
        switch self {
        case .fish: return "🐟"
        case .chicken: return "🍗"
        case .milk: return "🥛"
        }
    }

    public var displayName: String {
        switch self {
        case .fish: return "小鱼干"
        case .chicken: return "鸡腿"
        case .milk: return "牛奶"
        }
    }
}

/// 桌宠可执行的动作。由 PetView/WindowController 实现,测试用 mock。
public protocol PetActing: AnyObject {
    func updateGaze(towardScreenPoint point: CGPoint)
    func performBlink()
    func performPaw(towardViewPoint point: CGPoint)
    func performPounce(towardScreenPoint point: CGPoint)
    func performEat(_ food: FoodKind)
    func performLove()
    func setSleeping(_ sleeping: Bool)
}

/// 行为状态机:驱动视线跟随、点击互动、投喂/抚摸、打盹。
public final class BehaviorEngine {
    public enum State: Equatable {
        case idle, watching, pawing, pouncing, eating, loved, sleeping
    }

    public struct Tuning {
        public var doubleClickWindow: TimeInterval = 0.45
        public var sleepAfter: TimeInterval = 90
        public var wakeDistance: CGFloat = 140
        public var pawDuration: TimeInterval = 0.7
        public var pounceDuration: TimeInterval = 1.2
        public var eatDuration: TimeInterval = 2.6
        public var loveDuration: TimeInterval = 1.6
        public init() {}
    }

    public private(set) var state: State = .idle
    public weak var actor: PetActing?
    /// 桌宠当前屏幕位置(用于判断鼠标靠近唤醒)。
    public var petFrameProvider: () -> CGRect = { .zero }

    private let tuning: Tuning
    private let now: () -> Date
    private var lastInteraction: Date
    private var lastClick: Date?
    private var nextBlink: Date
    private var actionTimer: Timer?

    public init(tuning: Tuning = Tuning(), now: @escaping () -> Date = Date.init) {
        self.tuning = tuning
        self.now = now
        self.lastInteraction = now()
        self.nextBlink = now().addingTimeInterval(.random(in: 3...7))
    }

    deinit { actionTimer?.invalidate() }

    // MARK: - 输入事件

    public func handleMouseMoved(toScreenPoint point: CGPoint) {
        if state == .sleeping {
            let frame = petFrameProvider()
            let center = CGPoint(x: frame.midX, y: frame.midY)
            if hypot(point.x - center.x, point.y - center.y) < tuning.wakeDistance {
                wake()
            }
            return
        }
        guard state == .idle || state == .watching else { return }
        state = .watching
        actor?.updateGaze(towardScreenPoint: point)
    }

    /// 周期心跳(随鼠标轮询触发):处理入睡与眨眼。
    public func tick() {
        let current = now()
        if state == .idle || state == .watching {
            if current.timeIntervalSince(lastInteraction) > tuning.sleepAfter {
                state = .sleeping
                actor?.setSleeping(true)
                return
            }
            if current >= nextBlink {
                actor?.performBlink()
                nextBlink = current.addingTimeInterval(.random(in: 3...7))
            }
        }
    }

    /// 左键点击宠物:单击伸爪,快速连点扑捉鼠标。
    /// 伸爪(0.7s)比连点窗口(0.45s)长,所以连点的第二下必然落在
    /// pawing 期间——pawing 中的连点要能升级成扑捉,否则扑捉永远触发不了。
    public func handleClick(atViewPoint viewPoint: CGPoint, screenPoint: CGPoint) {
        touch()
        if state == .sleeping {
            wake()
            return
        }
        guard state == .idle || state == .watching || state == .pawing else { return }

        let current = now()
        let isDoubleClick = lastClick.map {
            current.timeIntervalSince($0) < tuning.doubleClickWindow
        } ?? false
        lastClick = current

        if isDoubleClick {
            state = .pouncing
            actor?.performPounce(towardScreenPoint: screenPoint)
            scheduleReturnToIdle(after: tuning.pounceDuration)
        } else if state != .pawing {
            state = .pawing
            actor?.performPaw(towardViewPoint: viewPoint)
            scheduleReturnToIdle(after: tuning.pawDuration)
        }
    }

    public func feed(_ food: FoodKind) {
        touch()
        guard interruptibleForMenuAction() else { return }
        state = .eating
        actor?.performEat(food)
        scheduleReturnToIdle(after: tuning.eatDuration)
    }

    public func petting() {
        touch()
        guard interruptibleForMenuAction() else { return }
        state = .loved
        actor?.performLove()
        scheduleReturnToIdle(after: tuning.loveDuration)
    }

    // MARK: - 内部

    private func interruptibleForMenuAction() -> Bool {
        if state == .sleeping { wake() }
        return state == .idle || state == .watching
    }

    private func wake() {
        state = .watching
        actor?.setSleeping(false)
        touch()
    }

    private func touch() {
        lastInteraction = now()
    }

    private func scheduleReturnToIdle(after duration: TimeInterval) {
        actionTimer?.invalidate()
        actionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) {
            [weak self] _ in
            self?.finishCurrentAction()
        }
    }

    /// 当前动作播完,回到 idle。暴露给测试直接调用。
    public func finishCurrentAction() {
        actionTimer?.invalidate()
        actionTimer = nil
        guard state != .sleeping else { return }
        state = .idle
        touch()
    }
}

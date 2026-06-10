import XCTest
@testable import CatOSKit

/// 记录动作调用的 mock。
private final class MockActor: PetActing {
    enum Action: Equatable {
        case gaze, blink, paw, pounce, eat(FoodKind), love, sleep(Bool)
    }
    var actions: [Action] = []

    func updateGaze(towardScreenPoint point: CGPoint) { actions.append(.gaze) }
    func performBlink() { actions.append(.blink) }
    func performPaw(towardViewPoint point: CGPoint) { actions.append(.paw) }
    func performPounce(towardScreenPoint point: CGPoint) { actions.append(.pounce) }
    func performEat(_ food: FoodKind) { actions.append(.eat(food)) }
    func performLove() { actions.append(.love) }
    func setSleeping(_ sleeping: Bool) { actions.append(.sleep(sleeping)) }
}

final class BehaviorEngineTests: XCTestCase {
    private var fakeNow = Date(timeIntervalSince1970: 1_000_000)
    private var actor: MockActor!
    private var engine: BehaviorEngine!

    override func setUp() {
        super.setUp()
        actor = MockActor()
        engine = BehaviorEngine(now: { self.fakeNow })
        engine.actor = actor
    }

    private func advance(_ seconds: TimeInterval) {
        fakeNow = fakeNow.addingTimeInterval(seconds)
    }

    func testMouseMoveEntersWatchingAndUpdatesGaze() {
        engine.handleMouseMoved(toScreenPoint: CGPoint(x: 10, y: 10))
        XCTAssertEqual(engine.state, .watching)
        XCTAssertEqual(actor.actions, [.gaze])
    }

    func testSingleClickTriggersPaw() {
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        XCTAssertEqual(engine.state, .pawing)
        XCTAssertEqual(actor.actions, [.paw])
    }

    func testRapidDoubleClickTriggersPounce() {
        // 真实场景:第二下点击落在伸爪动画期间,不调用 finishCurrentAction。
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        XCTAssertEqual(engine.state, .pawing)
        advance(0.2)
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        XCTAssertEqual(engine.state, .pouncing)
        XCTAssertEqual(actor.actions, [.paw, .pounce])
    }

    func testTripleClickDuringPawDoesNotRestartPaw() {
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        advance(0.6)  // 超出连点窗口,但仍在伸爪中
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        XCTAssertEqual(engine.state, .pawing)
        XCTAssertEqual(actor.actions, [.paw], "伸爪中的慢速点击不应重置动画")
    }

    func testSlowSecondClickIsAnotherPaw() {
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        engine.finishCurrentAction()
        advance(2)
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        XCTAssertEqual(engine.state, .pawing)
        XCTAssertEqual(actor.actions, [.paw, .paw])
    }

    func testClickIgnoredWhileBusy() {
        engine.feed(.fish)
        XCTAssertEqual(engine.state, .eating)
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        XCTAssertEqual(engine.state, .eating, "进食中点击不应打断")
        XCTAssertEqual(actor.actions, [.eat(.fish)])
    }

    func testFeedAndPetting() {
        engine.feed(.chicken)
        XCTAssertEqual(engine.state, .eating)
        engine.finishCurrentAction()

        engine.petting()
        XCTAssertEqual(engine.state, .loved)
        XCTAssertEqual(actor.actions, [.eat(.chicken), .love])
    }

    func testFallsAsleepAfterInactivity() {
        advance(91)
        engine.tick()
        XCTAssertEqual(engine.state, .sleeping)
        XCTAssertEqual(actor.actions, [.sleep(true)])
    }

    func testWakesWhenMouseComesClose() {
        engine.petFrameProvider = { CGRect(x: 0, y: 0, width: 100, height: 100) }
        advance(91)
        engine.tick()
        XCTAssertEqual(engine.state, .sleeping)

        // 远处移动:继续睡
        engine.handleMouseMoved(toScreenPoint: CGPoint(x: 2000, y: 2000))
        XCTAssertEqual(engine.state, .sleeping)

        // 靠近:醒来
        engine.handleMouseMoved(toScreenPoint: CGPoint(x: 80, y: 80))
        XCTAssertEqual(engine.state, .watching)
        XCTAssertEqual(actor.actions, [.sleep(true), .sleep(false)])
    }

    func testClickWakesSleepingPetWithoutPawing() {
        advance(91)
        engine.tick()
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        XCTAssertEqual(engine.state, .watching)
        XCTAssertEqual(actor.actions, [.sleep(true), .sleep(false)])
    }

    func testBlinkHappensPeriodicallyWhenAwake() {
        advance(8)  // 超过最大眨眼间隔 7s
        engine.tick()
        XCTAssertEqual(actor.actions, [.blink])
    }

    func testFinishActionReturnsToIdle() {
        engine.handleClick(atViewPoint: .zero, screenPoint: .zero)
        engine.finishCurrentAction()
        XCTAssertEqual(engine.state, .idle)
    }
}

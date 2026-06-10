import AppKit

/// 自测演示模式(CATOS_DEMO=1):进程内驱动行为引擎走一遍全部交互,
/// 在每个动作节点用 screencapture 截图到 CATOS_DEMO_OUT 目录。
/// 绕过的只是系统事件注入层(无辅助功能权限时无法模拟鼠标),
/// 引擎本身的输入分发逻辑由单元测试覆盖。
public enum DemoDirector {
    public static func runIfRequested(engine: BehaviorEngine, window: NSWindow?) {
        guard ProcessInfo.processInfo.environment["CATOS_DEMO"] == "1",
              let window else { return }
        let outPath = ProcessInfo.processInfo.environment["CATOS_DEMO_OUT"]
            ?? NSTemporaryDirectory() + "catos-demo"
        try? FileManager.default.createDirectory(
            atPath: outPath, withIntermediateDirectories: true
        )

        let frame = window.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let viewSize = window.frame.size

        func at(_ delay: TimeInterval, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        func capture(_ name: String, after delay: TimeInterval, widenLeft: CGFloat = 0) {
            at(delay) {
                let f = window.frame
                guard let screen = NSScreen.screens.first else { return }
                let topY = screen.frame.height - f.maxY - 30
                let region = String(
                    format: "-R%.0f,%.0f,%.0f,%.0f",
                    f.minX - 30 - widenLeft, topY,
                    f.width + 60 + widenLeft, f.height + 60
                )
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                p.arguments = ["-x", region, "\(outPath)/\(name).png"]
                try? p.run()
                print("demo capture: \(name)")
            }
        }

        // 1. 视线:看左上 → 看右下
        at(0.6) { engine.handleMouseMoved(toScreenPoint: CGPoint(x: center.x - 350, y: center.y + 260)) }
        capture("1_gaze_leftup", after: 1.2)
        at(1.8) { engine.handleMouseMoved(toScreenPoint: CGPoint(x: center.x + 350, y: center.y - 200)) }
        capture("2_gaze_rightdown", after: 2.4)

        // 2. 单击 → 伸爪(目标:视图内左下方)
        at(3.2) {
            engine.handleClick(
                atViewPoint: CGPoint(x: viewSize.width * 0.22, y: viewSize.height * 0.18),
                screenPoint: CGPoint(x: frame.minX + viewSize.width * 0.22,
                                     y: frame.minY + viewSize.height * 0.18)
            )
        }
        capture("3_paw_strike", after: 3.5)

        // 3. 投喂小鱼干
        at(4.8) { engine.feed(.fish) }
        capture("4_food_drop", after: 5.35)
        capture("5_eating_hearts", after: 7.0)

        // 4. 抚摸
        at(8.2) { engine.petting() }
        capture("6_love", after: 8.7)

        // 5. 连点 → 扑捉鼠标(目标:窗口左侧 260pt)
        let pounceTarget = CGPoint(x: center.x - 260, y: center.y + 40)
        at(10.0) {
            engine.handleClick(atViewPoint: CGPoint(x: viewSize.width / 2, y: viewSize.height / 2),
                               screenPoint: pounceTarget)
        }
        at(10.25) {
            engine.handleClick(atViewPoint: CGPoint(x: viewSize.width / 2, y: viewSize.height / 2),
                               screenPoint: pounceTarget)
        }
        capture("7_pounce_landed", after: 11.2, widenLeft: 340)

        at(12.2) { print("DEMO DONE") }
    }
}

import AppKit
import CatOSKit

let arguments = CommandLine.arguments
if arguments.count >= 4, arguments[1] == "--selftest" {
    exit(SelfTest.run(
        photoPath: arguments[2],
        outputPath: arguments[3],
        seed: arguments.contains("--seed")
    ))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

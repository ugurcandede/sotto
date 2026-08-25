import Cocoa

if CommandLine.arguments.dropFirst().first == "probe" {
    ProbeCommand.run()
    exit(0)
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()

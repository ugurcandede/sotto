import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let viewModel = MenuBarViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(viewModel: viewModel)
        installTerminationHandlers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.releaseMicKey()
    }

    /// A crash or `kill` must not leave the 🎤 key remapped — the remap
    /// outlives the process, and Dictation would stay dead.
    private func installTerminationHandlers() {
        for signalCode in [SIGTERM, SIGINT] {
            signal(signalCode, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalCode, queue: .main)
            source.setEventHandler { [weak self] in
                self?.viewModel.releaseMicKey()
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private var signalSources: [DispatchSourceSignal] = []
}

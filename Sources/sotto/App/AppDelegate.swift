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
        viewModel.releaseHold()
        viewModel.releaseMicKey()
    }

    /// A crash or `kill` while the hold key is down must not leave the mic in
    /// the inverted state.
    private func installTerminationHandlers() {
        for signalCode in [SIGTERM, SIGINT] {
            signal(signalCode, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalCode, queue: .main)
            source.setEventHandler { [weak self] in
                self?.viewModel.releaseHold()
                self?.viewModel.releaseMicKey()
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private var signalSources: [DispatchSourceSignal] = []
}

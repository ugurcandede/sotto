import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let viewModel: MenuBarViewModel

    init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        let hosting = NSHostingController(rootView: MenuView(viewModel: viewModel))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusItem.length = 18
        installIcon()
    }

    @objc private func handleClick() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true

        // Push-to-talk owns the mute state; a stray click must not unmute you.
        if isRightClick || viewModel.mode == .hold {
            togglePopover()
        } else {
            viewModel.toggle()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // Same affordance as a native menu bar item: the slot stays lit while
        // its menu is open.
        button.highlight(true)
        viewModel.refreshOnOpen()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        let window = popover.contentViewController?.view.window
        window?.makeKey()
        // Becoming key hands first responder to the first control in the key
        // view loop, which draws a focus ring on the Mute button. Nothing in
        // the popover wants focus until it is clicked.
        window?.makeFirstResponder(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    private func installIcon() {
        guard let button = statusItem.button else { return }
        let host = PassthroughHostingView(rootView: StatusIcon(viewModel: viewModel))
        host.frame = NSRect(x: 0, y: 0, width: 18, height: 22)
        host.autoresizingMask = [.width, .height]
        button.addSubview(host)
    }
}

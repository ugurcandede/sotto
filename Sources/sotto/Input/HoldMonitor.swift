import Cocoa

/// Hold-to-override. `RegisterEventHotKey` never reports key-up, so this needs
/// a `CGEventTap` — the only part of the app that asks for a permission.
final class HoldMonitor {
    var onHoldChange: ((Bool) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var key: KeyCombo = .defaultHold
    private var isHeld = false

    static var hasPermission: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start(key: KeyCombo) -> Bool {
        stop()
        self.key = key
        // Require the grant up front: on newer macOS an unauthorized tapCreate
        // no longer fails — it "succeeds" with keyDown/keyUp silently stripped
        // from the mask, which would leave the app thinking it is armed.
        guard HoldMonitor.hasPermission else {
            HoldMonitor.requestPermission()
            return false
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        // Active tap so the bound key can be swallowed; that ties the tap to
        // the Accessibility permission (listen-only would be Input Monitoring,
        // but then a non-modifier key auto-repeats into the focused app).
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HoldMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        report(false)
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables a tap that takes too long or when the user
        // triggers a secure input transition; without this the app silently
        // stops working after a while.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == key.keyCode else { return Unmanaged.passUnretained(event) }

        if type == .flagsChanged {
            guard let mask = key.deviceMask else { return Unmanaged.passUnretained(event) }
            report(event.flags.rawValue & mask != 0)
            // Never swallow a modifier — that would break every other shortcut.
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
        report(type == .keyDown)
        return nil
    }

    private func report(_ held: Bool) {
        guard held != isHeld else { return }
        isHeld = held
        DispatchQueue.main.async { [weak self] in self?.onHoldChange?(held) }
    }

    deinit { stop() }
}

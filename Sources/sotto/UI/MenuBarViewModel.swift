import Combine
import CoreAudio
import ServiceManagement
import SwiftUI

struct InputChoice: Identifiable, Hashable {
    /// The device UID, not the `AudioObjectID` — CoreAudio renumbers object
    /// IDs whenever a device re-enumerates (an AirPods reconnect is enough),
    /// and a write to a stale ID succeeds silently without doing anything.
    let id: String
    let name: String
}

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var muted = false
    @Published private(set) var baseMuted = false
    @Published private(set) var pulseTrigger = 0
    @Published private(set) var holdActive = false
    @Published private(set) var deviceName = ""
    @Published private(set) var strategyName = ""
    @Published private(set) var deviceSupported = true
    @Published private(set) var inputs: [InputChoice] = []
    @Published private(set) var selectedInput: String = ""
    @Published private(set) var switchWarning: String?
    @Published private(set) var inputVolume: Float = 0
    @Published private(set) var canAdjustVolume = false

    /// One binding: a mode and the key that drives it.
    @Published var mode = Settings.mode { didSet { modeChanged() } }
    @Published var key: KeyCombo? = Settings.key { didSet { Settings.key = key; applyBinding() } }
    @Published private(set) var needsAccessibility = false

    @Published var showHUD = Settings.showHUD { didSet { Settings.showHUD = showHUD } }

    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled { didSet { applyLaunchAtLogin() } }

    private let coordinator = MuteCoordinator(audio: AudioController())
    private let toggleHotkey = ToggleHotkey()
    private let holdMonitor = HoldMonitor()
    private let hud = HUDController()
    let levelMeter = LevelMeter()

    init() {
        coordinator.onChange = { [weak self] in self?.refresh() }
        coordinator.audio.onDeviceListChanged = { [weak self] in self?.refreshDevices() }
        toggleHotkey.onTrigger = { [weak self] in self?.toggle() }
        holdMonitor.onHoldChange = { [weak self] held in self?.coordinator.setHold(held) }

        applyBinding()
        if mode == .hold { coordinator.setBase(true) }
        refreshDevices()
        refresh()
    }

    /// The mic key reaches us as F13; say "🎤" so the hint matches the keycap.
    var keyLabel: String {
        guard let key else { return "no key" }
        return key == DictationKey.combo ? "🎤" : key.display
    }

    var usesMicKey: Bool {
        key == DictationKey.combo
    }

    var statusText: String {
        if !deviceSupported { return "Not supported" }
        return muted ? "Muted" : "Unmuted"
    }

    func selectInput(_ uid: String) {
        switchWarning = nil
        refreshDevices()

        guard let device = coordinator.audio.inputs.first(where: { $0.uid == uid }) else {
            switchWarning = "That device is no longer available."
            refresh()
            return
        }
        let name = device.name
        coordinator.audio.selectInput(device)

        // macOS refuses some inputs (a Continuity mic with the phone asleep,
        // AirPods mid-reconnect) by silently reverting a moment later.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }
            self.refresh()
            if self.selectedInput != uid {
                self.switchWarning = "macOS kept the previous input — \(name) isn't available right now."
            }
        }
    }

    func setVolume(_ volume: Float) {
        coordinator.audio.setInputVolume(volume)
        inputVolume = volume
    }

    func refreshDevices() {
        inputs = coordinator.audio.inputs.map { InputChoice(id: $0.uid, name: $0.name) }
    }

    func toggle() {
        coordinator.toggle()
        if showHUD { hud.show(muted: coordinator.effectiveMute, device: coordinator.audio.deviceName) }
    }

    func releaseHold() {
        coordinator.setHold(false)
    }

    /// Permission may have been granted in System Settings while we were idle.
    /// Called when the popover opens — devices come and go while it is closed.
    func refreshOnOpen() {
        switchWarning = nil
        refreshDevices()
        refreshPermission()
        refresh()
    }

    func refreshPermission() {
        if mode == .hold, !holdMonitor.isRunning, HoldMonitor.hasPermission {
            applyBinding()
        }
        needsAccessibility = mode == .hold && !HoldMonitor.hasPermission
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func refresh() {
        if coordinator.holdActive != holdActive { holdStateChanged(coordinator.holdActive) }
        if muted != coordinator.effectiveMute { pulseTrigger += 1 }
        muted = coordinator.effectiveMute
        baseMuted = coordinator.baseMuted
        holdActive = coordinator.holdActive
        deviceName = coordinator.audio.deviceName
        strategyName = coordinator.audio.strategyName
        deviceSupported = coordinator.audio.isSupported
        selectedInput = coordinator.audio.device?.uid ?? ""
        inputVolume = coordinator.audio.inputVolume
        canAdjustVolume = coordinator.audio.canAdjustVolume
    }

    private func modeChanged() {
        Settings.mode = mode
        // Push-to-talk rests muted: the key is what opens the mic.
        if mode == .hold { coordinator.setBase(true) }
        if mode == .hold, !HoldMonitor.hasPermission {
            HoldMonitor.requestPermission()
        }
        applyBinding()
    }

    /// Toggle runs on a Carbon hotkey (no permission); push-to-talk needs the
    /// event tap because Carbon never reports key-up.
    private func applyBinding() {
        applyMicMapping()
        toggleHotkey.unregister()
        holdMonitor.stop()
        coordinator.setHold(false)
        needsAccessibility = false

        guard let key else { return }

        switch mode {
        case .toggle:
            toggleHotkey.register(key)
        case .hold:
            needsAccessibility = !holdMonitor.start(key: key)
        }
    }

    /// While the key is down the HUD stays up, so you can see you are live
    /// without looking at the menu bar.
    private func holdStateChanged(_ held: Bool) {
        guard showHUD else { return }
        if held {
            hud.show(muted: coordinator.effectiveMute, device: coordinator.audio.deviceName, sticky: true)
        } else {
            hud.hide()
        }
    }

    /// The HID remap is a side effect of the key assignment, and it outlives the
    /// process — so clear it whenever the mic key is no longer bound.
    private func applyMicMapping() {
        if usesMicKey {
            DictationKey.map()
        } else if DictationKey.isMapped {
            DictationKey.unmap()
        }
    }

    /// Called on quit: dictation should work again once sotto is gone.
    func releaseMicKey() {
        if DictationKey.isMapped { DictationKey.unmap() }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

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
    @Published private(set) var pulseTrigger = 0
    @Published private(set) var deviceName = ""
    @Published private(set) var strategyName = ""
    @Published private(set) var deviceSupported = true
    @Published private(set) var inputs: [InputChoice] = []
    @Published private(set) var selectedInput: String = ""
    @Published private(set) var switchWarning: String?
    @Published private(set) var inputVolume: Float = 0
    @Published private(set) var canAdjustVolume = false

    @Published var key: KeyCombo? = Settings.key { didSet { Settings.key = key; applyBinding() } }

    @Published var showHUD = Settings.showHUD { didSet { Settings.showHUD = showHUD } }

    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled { didSet { applyLaunchAtLogin() } }

    private let audio: AudioController
    private let coordinator: MuteCoordinator<AudioController>
    private let toggleHotkey = ToggleHotkey()
    private let hud = HUDController()
    let levelMeter = LevelMeter()

    init() {
        let audio = AudioController()
        self.audio = audio
        coordinator = MuteCoordinator(audio: audio)

        coordinator.onChange = { [weak self] in self?.refresh() }
        audio.onDeviceListChanged = { [weak self] in self?.refreshDevices() }
        toggleHotkey.onTrigger = { [weak self] in self?.toggle() }

        applyBinding()
        refreshDevices()
        refresh()
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

        guard let device = audio.inputs.first(where: { $0.uid == uid }) else {
            switchWarning = "That device is no longer available."
            refresh()
            return
        }
        let name = device.name
        audio.selectInput(device)

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
        audio.setInputVolume(volume)
        inputVolume = volume
    }

    func refreshDevices() {
        inputs = audio.inputs.map { InputChoice(id: $0.uid, name: $0.name) }
    }

    func toggle() {
        coordinator.toggle()
        if showHUD { hud.show(muted: coordinator.muted, device: audio.deviceName) }
    }

    /// Called when the popover opens — devices come and go while it is closed.
    func refreshOnOpen() {
        switchWarning = nil
        refreshDevices()
        refresh()
    }

    private func refresh() {
        if muted != coordinator.muted { pulseTrigger += 1 }
        muted = coordinator.muted
        deviceName = audio.deviceName
        strategyName = audio.strategyName
        deviceSupported = audio.isSupported
        selectedInput = audio.device?.uid ?? ""
        inputVolume = audio.inputVolume
        canAdjustVolume = audio.canAdjustVolume
    }

    private func applyBinding() {
        applyMicMapping()
        toggleHotkey.unregister()
        guard let key else { return }
        toggleHotkey.register(key)
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

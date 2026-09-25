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
    @Published var mode = Settings.mode {
        didSet { modeChanged(); trackSetting("mode", mode.rawValue, oldValue != mode) }
    }
    @Published var key: KeyCombo? = Settings.key {
        didSet { Settings.key = key; applyBinding(); trackSetting("key", keyType, oldValue != key) }
    }
    @Published private(set) var needsAccessibility = false
    @Published private(set) var staleAccessibility = false

    @Published var showHUD = Settings.showHUD {
        didSet { Settings.showHUD = showHUD; trackSetting("show_hud", showHUD, oldValue != showHUD) }
    }

    @Published var sendUsageStats = Settings.analyticsEnabled {
        didSet {
            Settings.analyticsEnabled = sendUsageStats
            if !sendUsageStats { Analytics.disabled() }
            // Only lands when turned on: analytics is off otherwise.
            trackSetting("usage_stats", sendUsageStats, oldValue != sendUsageStats)
        }
    }

    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            applyLaunchAtLogin()
            trackSetting("launch_at_login", launchAtLogin, oldValue != launchAtLogin)
        }
    }

    @Published private(set) var availableUpdate: AppUpdate?
    @Published private(set) var updateState: UpdateState = .idle

    enum UpdateState { case idle, updating, notInBrewYet, failed }
    private var updateBannerTrackedVersion: String?

    // Analytics: activity since the last heartbeat. Push-to-talk can fire
    // hundreds of times a meeting, so holds are summarised, not sent one by one.
    private var toggleCount = 0
    private var holdCount = 0
    private var holdSeconds: TimeInterval = 0
    private var longestHold: TimeInterval = 0
    private var holdStartedAt: Date?
    private var lastTrackedInput: String?

    private let coordinator = MuteCoordinator(audio: AudioController())
    private let toggleHotkey = ToggleHotkey()
    private let holdMonitor = HoldMonitor()
    private let hud = HUDController()
    let levelMeter = LevelMeter()

    init() {
        coordinator.onChange = { [weak self] in self?.refresh() }
        coordinator.audio.onDeviceListChanged = { [weak self] in self?.refreshDevices() }
        toggleHotkey.onTrigger = { [weak self] in self?.toggle(source: "hotkey") }
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
        if !deviceSupported { return "not supported" }
        return muted ? "muted" : "unmuted"
    }

    func selectInput(_ uid: String) {
        switchWarning = nil
        refreshDevices()

        guard let device = coordinator.audio.inputs.first(where: { $0.uid == uid }) else {
            switchWarning = "that device is no longer available."
            Analytics.track("input_switched", ["result": "unavailable"])
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
            let kept = self.selectedInput != uid
            Analytics.track("input_switched", ["result": kept ? "reverted" : "ok", "strategy": self.strategyName])
            if kept {
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

    func toggle(source: String = "menu") {
        coordinator.toggle()
        toggleCount += 1
        Analytics.track("mute_toggled", ["muted": coordinator.effectiveMute, "source": source])
        if showHUD { hud.show(muted: coordinator.effectiveMute, device: coordinator.audio.deviceName) }
    }

    func releaseHold() {
        coordinator.setHold(false)
    }

    /// Permission may have been granted in System Settings while we were idle.
    /// Called when the popover opens — devices come and go while it is closed.
    func refreshOnOpen() {
        switchWarning = nil
        permissionPollTicks = 0
        refreshDevices()
        refreshPermission()
        refresh()
        Analytics.track("popover_opened", [
            "mode": mode.rawValue,
            "muted": muted,
            "needs_accessibility": needsAccessibility,
        ])
        if let update = availableUpdate, updateBannerTrackedVersion != update.version {
            updateBannerTrackedVersion = update.version
            Analytics.track("update_banner_shown", ["latest_version": update.version])
        }
    }

    // MARK: - Analytics

    /// The kind of key bound, never the key itself.
    var keyType: String {
        guard let key else { return "none" }
        if key == DictationKey.combo { return "mic_key" }
        if key.isModifierKey { return "modifier_only" }
        if key.isFunctionKey { return "function_key" }
        return "combo"
    }

    private func trackSetting(_ name: String, _ value: Any, _ changed: Bool) {
        guard changed else { return }
        refreshUserProperties() // first, so the event carries the new values
        Analytics.track("setting_changed", ["setting": name, "value": "\(value)"])
    }

    /// Settings worth slicing every report by.
    func refreshUserProperties() {
        Analytics.setUserProperties([
            "trigger_mode": mode.rawValue,
            "key_type": keyType,
            "show_hud": showHUD,
            "launch_at_login": launchAtLogin,
            "input_count": inputs.count,
        ])
    }

    /// Activity summary for the periodic heartbeat; nil when nothing happened,
    /// so an idle sotto does not count as active.
    func heartbeatParams() -> [String: Any]? {
        guard toggleCount > 0 || holdCount > 0 || holdStartedAt != nil else { return nil }
        defer {
            toggleCount = 0
            holdCount = 0
            holdSeconds = 0
            longestHold = 0
        }
        return [
            "mode": mode.rawValue,
            "muted": muted,
            "toggles": toggleCount,
            "holds": holdCount,
            "hold_sec": Int(holdSeconds),
            "max_hold_sec": Int(longestHold),
        ]
    }

    private func recordHold(_ held: Bool) {
        if held {
            holdStartedAt = Date()
            return
        }
        guard let start = holdStartedAt else { return }
        holdStartedAt = nil
        let duration = Date().timeIntervalSince(start)
        holdCount += 1
        holdSeconds += duration
        longestHold = max(longestHold, duration)
        // The coordinator's failsafe releases a hold after 120 s; a hold that
        // long almost always means a missed key-up, which is worth seeing.
        if duration >= 119 { Analytics.track("hold_failsafe", ["mode": mode.rawValue]) }
    }

    // MARK: - Updates

    func checkForUpdates() {
        UpdateChecker.check { [weak self] update in
            Task { @MainActor in self?.availableUpdate = update }
        }
    }

    /// Homebrew installs upgrade in place, then quit and reopen; anything else
    /// gets the release page.
    func performUpdate() {
        guard let update = availableUpdate, updateState != .updating else { return }
        guard let prefix = UpdateChecker.brewPrefix else {
            Analytics.track("update_started", ["latest_version": update.version, "result": "release_page"])
            NSWorkspace.shared.open(update.url)
            return
        }
        Analytics.track("update_started", ["latest_version": update.version, "result": "brew"])
        updateState = .updating
        UpdateChecker.upgrade(prefix: prefix) { [weak self] succeeded in
            Task { @MainActor in
                if succeeded, let installed = UpdateChecker.installedVersion, installed != Analytics.appVersion {
                    UpdateChecker.relaunchAfterExit()
                    NSApp.terminate(nil)
                    return
                }
                self?.updateState = succeeded ? .notInBrewYet : .failed
                Analytics.track("update_failed", [
                    "latest_version": update.version,
                    "reason": succeeded ? "not_in_brew_yet" : "brew_error",
                ])
            }
        }
    }

    func openUpdateLog() {
        NSWorkspace.shared.open(UpdateChecker.logURL)
    }

    func dismissUpdate() {
        guard let update = availableUpdate else { return }
        Analytics.track("update_dismissed", ["latest_version": update.version])
        UpdateChecker.dismissedVersion = update.version
        availableUpdate = nil
    }

    func refreshPermission() {
        let wasNeeded = needsAccessibility
        if mode == .hold, !holdMonitor.isRunning, HoldMonitor.hasPermission {
            applyBinding()
        }
        needsAccessibility = mode == .hold && !HoldMonitor.hasPermission
        if wasNeeded && !needsAccessibility { Analytics.track("accessibility_granted") }
        updatePermissionPoll()
    }

    /// The grant lands in System Settings while sotto sits in the background,
    /// and TCC sends no notification — so while the notice is up, poll until
    /// the grant appears and arm the tap without waiting for the menu. The
    /// poll gives up after a few minutes; opening the menu or the settings
    /// link starts it again.
    private var permissionPoll: Timer?
    private var permissionPollTicks = 0
    private let permissionPollLimit = 150 // 5 minutes at 2 s

    private func updatePermissionPoll() {
        staleAccessibility = needsAccessibility && Settings.hadAccessibility
        if staleAccessibility { resetStaleGrant() }
        if needsAccessibility {
            guard permissionPoll == nil else { return }
            permissionPollTicks = 0
            permissionPoll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.pollPermission() }
            }
        } else {
            permissionPoll?.invalidate()
            permissionPoll = nil
        }
    }

    private func pollPermission() {
        permissionPollTicks += 1
        guard permissionPollTicks <= permissionPollLimit else {
            permissionPoll?.invalidate()
            permissionPoll = nil
            return
        }
        refreshPermission()
    }

    /// An update changes the ad-hoc signature, so the recorded grant can never
    /// match again — while System Settings still shows sotto as enabled. Clear
    /// the dead record and ask again, so the user gets a working prompt
    /// instead of a toggle that is already on.
    private var staleGrantHandled = false

    private func resetStaleGrant() {
        guard !staleGrantHandled else { return }
        staleGrantHandled = true
        Analytics.track("accessibility_stale_reset")
        let reset = Process()
        reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        reset.arguments = ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "com.ugurcandede.sotto"]
        reset.terminationHandler = { _ in
            DispatchQueue.main.async { HoldMonitor.requestPermission() }
        }
        try? reset.run()
    }

    func openAccessibilitySettings() {
        Analytics.track("accessibility_settings_opened")
        permissionPollTicks = 0
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func refresh() {
        if coordinator.holdActive != holdActive {
            recordHold(coordinator.holdActive)
            holdStateChanged(coordinator.holdActive)
        }
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

        // Sends the mute strategy the new device needs, never its name or UID.
        if selectedInput != lastTrackedInput {
            if lastTrackedInput != nil {
                Analytics.track("device_changed", ["strategy": strategyName, "supported": deviceSupported])
            }
            lastTrackedInput = selectedInput
        }
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
            if needsAccessibility { Analytics.track("accessibility_needed") }
            if !needsAccessibility { Settings.hadAccessibility = true }
        }
        updatePermissionPoll()
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

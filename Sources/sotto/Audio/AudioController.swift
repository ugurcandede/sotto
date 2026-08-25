import CoreAudio
import Foundation

/// The only place in the app that writes to CoreAudio.
final class AudioController {
    private(set) var device: AudioDevice?
    private(set) var strategy: MuteStrategy?

    /// Fired when the device reports a state we did not ask for — System
    /// Settings, another app, or a device swap.
    var onExternalChange: ((Bool) -> Void)?
    var onDeviceChanged: (() -> Void)?
    var onDeviceListChanged: (() -> Void)?

    private let systemObserver = DeviceObserver()
    private var deviceObserver = DeviceObserver()
    fileprivate var desiredMute = false
    fileprivate var lastWriteAt: CFAbsoluteTime = 0

    /// Property listeners also fire for our own writes; ignore anything that
    /// lands inside this window after one.
    private let writeGrace: CFAbsoluteTime = 0.2

    init() {
        systemObserver.observe(
            AudioDevice.address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal),
            on: AudioDevice.systemObject.id
        ) { [weak self] in
            self?.adoptDefaultDevice()
        }
        systemObserver.observe(
            AudioDevice.address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal),
            on: AudioDevice.systemObject.id
        ) { [weak self] in
            self?.onDeviceListChanged?()
        }
        selectDefaultDevice()
        // Adopt whatever the device already is, so a later device switch
        // carries the real state over instead of a default `false`.
        desiredMute = actualMuted() ?? false
    }

    var deviceName: String { device?.name ?? "No input device" }
    var strategyName: String { strategy?.name ?? "unsupported" }
    var isSupported: Bool { strategy != nil }

    func actualMuted() -> Bool? {
        guard let device, let strategy else { return nil }
        return strategy.currentlyMuted(on: device)
    }

    func apply(_ muted: Bool) {
        desiredMute = muted
        guard let device, let strategy else { return }
        lastWriteAt = CFAbsoluteTimeGetCurrent()
        try? strategy.apply(muted, to: device)
    }

    // MARK: - Device lifecycle

    private func selectDefaultDevice() {
        device = AudioDevice.defaultInput
        strategy = device.flatMap(MuteStrategyFactory.strategy(for:))
        attachDeviceListeners()
    }

    /// Default input changed (AirPods connected, dock unplugged). Carry the
    /// intended state over to the new device — otherwise the icon lies.
    private func adoptDefaultDevice() {
        deviceObserver.stop()
        deviceObserver = DeviceObserver()
        selectDefaultDevice()
        apply(desiredMute)
        onDeviceChanged?()
    }

    private func attachDeviceListeners() {
        guard let device else { return }
        for selector in [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] {
            let address = AudioDevice.address(selector, element: kAudioObjectPropertyElementWildcard)
            deviceObserver.observe(address, on: device.id) { [weak self] in
                self?.deviceStateChanged()
            }
        }
    }

    private func deviceStateChanged() {
        guard let device, let strategy, let actual = strategy.currentlyMuted(on: device) else { return }

        // Watchdog: Zoom's automatic gain control raises input volume behind
        // our back, which silently un-mutes the volume-scalar fallback.
        if strategy.needsWatchdog, desiredMute, !actual, CFAbsoluteTimeGetCurrent() - lastWriteAt > writeGrace {
            apply(true)
            return
        }

        onExternalChange?(actual)
    }
}

// MARK: - Device selection and input gain

extension AudioController {
    var inputs: [AudioDevice] { AudioDevice.allInputs }

    func selectInput(_ device: AudioDevice) {
        // The default-device listener does the rest: strategy, listeners, state.
        try? AudioDevice.makeDefaultInput(device)
    }

    private var volumeElements: [AudioObjectPropertyElement] {
        guard let device else { return [] }
        return PropertySupport.settableElements(kAudioDevicePropertyVolumeScalar, on: device)
    }

    /// Muting through the volume fallback owns the volume value, so the slider
    /// can't be trusted (or written) while that device is muted.
    var canAdjustVolume: Bool {
        guard !volumeElements.isEmpty else { return false }
        return !(strategy?.needsWatchdog == true && desiredMute)
    }

    var inputVolume: Float {
        guard let device, let element = volumeElements.first else { return 0 }
        return (try? device.read(AudioDevice.address(kAudioDevicePropertyVolumeScalar, element: element), as: Float32.self)) ?? 0
    }

    func setInputVolume(_ volume: Float) {
        guard let device, canAdjustVolume else { return }
        lastWriteAt = CFAbsoluteTimeGetCurrent()
        for element in volumeElements {
            try? device.write(Float32(volume), to: AudioDevice.address(kAudioDevicePropertyVolumeScalar, element: element))
        }
    }
}

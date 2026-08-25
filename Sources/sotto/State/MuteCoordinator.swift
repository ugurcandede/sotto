import Foundation

/// `effectiveMute = baseMuted XOR holdActive`. Every mute decision in the app
/// goes through here; `AudioController` only executes it.
final class MuteCoordinator {
    private(set) var baseMuted = false
    private(set) var holdActive = false

    var onChange: (() -> Void)?

    let audio = AudioController()

    /// A missed key-up (sleep, app losing focus) would strand the mic in the
    /// held state forever.
    private var holdFailsafe: Timer?
    private let holdTimeout: TimeInterval = 30

    var effectiveMute: Bool { baseMuted != holdActive }

    init() {
        audio.onExternalChange = { [weak self] actual in self?.adopt(actual) }
        audio.onDeviceChanged = { [weak self] in self?.onChange?() }
        baseMuted = audio.actualMuted() ?? false
    }

    func toggle() {
        baseMuted.toggle()
        push()
    }

    func setBase(_ muted: Bool) {
        guard muted != baseMuted else { return }
        baseMuted = muted
        push()
    }

    func setHold(_ active: Bool) {
        guard active != holdActive else { return }
        holdActive = active

        holdFailsafe?.invalidate()
        if active {
            holdFailsafe = Timer.scheduledTimer(withTimeInterval: holdTimeout, repeats: false) { [weak self] _ in
                self?.setHold(false)
            }
        }
        push()
    }

    /// The device changed underneath us — believe the hardware, not our state.
    private func adopt(_ actualMuted: Bool) {
        baseMuted = actualMuted != holdActive
        onChange?()
    }

    private func push() {
        audio.apply(effectiveMute)
        onChange?()
    }
}

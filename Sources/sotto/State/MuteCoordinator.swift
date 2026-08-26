import Foundation

/// Every mute decision in the app goes through here; the engine only executes
/// it. (Push-to-talk lived here as `baseMuted XOR holdActive` — recover it
/// from the history of this file when that mode returns.)
final class MuteCoordinator<Engine: MuteEngine> {
    private(set) var muted = false

    var onChange: (() -> Void)?

    private let audio: Engine

    init(audio: Engine) {
        self.audio = audio
        audio.onExternalChange = { [weak self] actual in self?.adopt(actual) }
        audio.onDeviceChanged = { [weak self] in self?.onChange?() }
        muted = audio.actualMuted() ?? false
    }

    func toggle() {
        muted.toggle()
        push()
    }

    /// The device changed underneath us — believe the hardware, not our state.
    private func adopt(_ actualMuted: Bool) {
        muted = actualMuted
        onChange?()
    }

    private func push() {
        audio.apply(muted)
        onChange?()
    }
}

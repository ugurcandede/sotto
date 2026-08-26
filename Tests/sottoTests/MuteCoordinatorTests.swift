import Foundation
import Testing

@testable import sotto

/// Records what the coordinator asked the audio layer to do, and lets a test
/// play the part of the hardware changing underneath it.
private final class FakeEngine: MuteEngine {
    var onExternalChange: ((Bool) -> Void)?
    var onDeviceChanged: (() -> Void)?

    var reported: Bool?
    private(set) var applied: [Bool] = []

    init(reported: Bool? = false) {
        self.reported = reported
    }

    func actualMuted() -> Bool? { reported }

    func apply(_ muted: Bool) {
        applied.append(muted)
    }
}

@Suite("MuteCoordinator")
struct MuteCoordinatorTests {

    private func make(reported: Bool? = false) -> (MuteCoordinator<FakeEngine>, FakeEngine) {
        let engine = FakeEngine(reported: reported)
        return (MuteCoordinator(audio: engine), engine)
    }

    // MARK: - Startup

    @Test func adoptsTheDeviceStateOnLaunch() {
        let (muted, _) = make(reported: true)
        #expect(muted.muted)

        let (unmuted, _) = make(reported: false)
        #expect(!unmuted.muted)
    }

    /// An unsupported device reports nothing; assume unmuted rather than
    /// claiming a mute the app cannot actually enforce.
    @Test func unknownDeviceStateStartsUnmuted() {
        let (coordinator, _) = make(reported: nil)
        #expect(!coordinator.muted)
    }

    @Test func startupDoesNotWriteToTheDevice() {
        let (_, engine) = make(reported: true)
        #expect(engine.applied.isEmpty)
    }

    // MARK: - Toggle

    @Test func togglePushesEachFlip() {
        let (coordinator, engine) = make()
        coordinator.toggle()
        coordinator.toggle()
        #expect(engine.applied == [true, false])
    }

    @Test func changeCallbackFiresOnEveryPush() {
        let (coordinator, _) = make()
        var changes = 0
        coordinator.onChange = { changes += 1 }
        coordinator.toggle()
        coordinator.toggle()
        #expect(changes == 2)
    }

    // MARK: - External change

    @Test func externalChangeIsBelievedOverLocalState() {
        let (coordinator, engine) = make()
        engine.onExternalChange?(true)
        #expect(coordinator.muted)
    }

    /// Believing the hardware must not echo the value back — that write would
    /// retrigger the listener that reported it.
    @Test func externalChangeDoesNotWriteBack() {
        let (coordinator, engine) = make()
        engine.onExternalChange?(true)
        #expect(engine.applied.isEmpty)
        #expect(coordinator.muted)
    }

    @Test func deviceChangeNotifiesTheUI() {
        let (coordinator, engine) = make()
        var changes = 0
        coordinator.onChange = { changes += 1 }
        engine.onDeviceChanged?()
        #expect(changes == 1)
    }
}

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

    // MARK: - The invariant

    @Test(arguments: [
        (false, false, false),
        (true, false, true),
        (false, true, true),
        (true, true, false),
    ])
    func effectiveMuteIsBaseXorHold(_ base: Bool, _ hold: Bool, _ expected: Bool) {
        let (coordinator, _) = make()
        coordinator.setBase(base)
        coordinator.setHold(hold)
        #expect(coordinator.effectiveMute == expected)
    }

    // MARK: - Startup

    @Test func adoptsTheDeviceStateOnLaunch() {
        let (muted, _) = make(reported: true)
        #expect(muted.baseMuted)
        #expect(muted.effectiveMute)

        let (unmuted, _) = make(reported: false)
        #expect(!unmuted.baseMuted)
    }

    /// An unsupported device reports nothing; assume unmuted rather than
    /// claiming a mute the app cannot actually enforce.
    @Test func unknownDeviceStateStartsUnmuted() {
        let (coordinator, _) = make(reported: nil)
        #expect(!coordinator.baseMuted)
    }

    @Test func startupDoesNotWriteToTheDevice() {
        let (_, engine) = make(reported: true)
        #expect(engine.applied.isEmpty)
    }

    // MARK: - Toggle and base

    @Test func togglePushesEachFlip() {
        let (coordinator, engine) = make()
        coordinator.toggle()
        coordinator.toggle()
        #expect(engine.applied == [true, false])
    }

    @Test func settingTheSameBaseIsANoop() {
        let (coordinator, engine) = make()
        coordinator.setBase(true)
        coordinator.setBase(true)
        #expect(engine.applied == [true])
    }

    @Test func changeCallbackFiresOnEveryPush() {
        let (coordinator, _) = make()
        var changes = 0
        coordinator.onChange = { changes += 1 }
        coordinator.toggle()
        coordinator.setBase(false)
        coordinator.setHold(true)
        #expect(changes == 3)
    }

    // MARK: - Hold

    @Test func holdMutesWhenBaseIsOpen() {
        let (coordinator, engine) = make()
        coordinator.setHold(true)
        #expect(engine.applied == [true])
        coordinator.setHold(false)
        #expect(engine.applied == [true, false])
    }

    /// Push-to-talk: base is muted, so holding opens the mic.
    @Test func holdOpensTheMicWhenBaseIsMuted() {
        let (coordinator, engine) = make()
        coordinator.setBase(true)
        coordinator.setHold(true)
        #expect(!coordinator.effectiveMute)
        #expect(engine.applied == [true, false])
    }

    @Test func repeatedHoldIsANoop() {
        let (coordinator, engine) = make()
        coordinator.setHold(true)
        coordinator.setHold(true)
        #expect(engine.applied == [true])
    }

    @Test func releasingHoldRestoresTheBaseState() {
        let (coordinator, _) = make()
        coordinator.setBase(true)
        coordinator.setHold(true)
        coordinator.setHold(false)
        #expect(coordinator.effectiveMute)
        #expect(coordinator.baseMuted)
    }

    // MARK: - External change

    @Test func externalChangeIsBelievedOverLocalState() {
        let (coordinator, engine) = make()
        engine.onExternalChange?(true)
        #expect(coordinator.baseMuted)
        #expect(coordinator.effectiveMute)
    }

    /// The hardware value already includes the hold inversion, so the base has
    /// to be backed out of it — otherwise releasing the key flips the wrong way.
    @Test func externalChangeDuringHoldBacksOutTheInversion() {
        let (coordinator, engine) = make()
        coordinator.setHold(true)
        engine.onExternalChange?(false)
        #expect(coordinator.baseMuted)
        coordinator.setHold(false)
        #expect(coordinator.effectiveMute)
    }

    @Test func externalChangeDoesNotWriteBack() {
        let (coordinator, engine) = make()
        engine.onExternalChange?(true)
        #expect(engine.applied.isEmpty)
        #expect(coordinator.baseMuted)
    }

    @Test func deviceChangeNotifiesTheUI() {
        let (coordinator, engine) = make()
        var changes = 0
        coordinator.onChange = { changes += 1 }
        engine.onDeviceChanged?()
        #expect(changes == 1)
    }

    // MARK: - Failsafe

    /// A missed key-up must not strand the mic; the hold expires on its own.
    @Test @MainActor func holdExpiresAfterTheTimeout() async throws {
        let engine = FakeEngine()
        let coordinator = MuteCoordinator(audio: engine, holdTimeout: 0.05)
        coordinator.setHold(true)
        #expect(coordinator.holdActive)

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(!coordinator.holdActive)
        #expect(engine.applied == [true, false])
    }

    @Test @MainActor func releasingHoldCancelsTheFailsafe() async throws {
        let engine = FakeEngine()
        let coordinator = MuteCoordinator(audio: engine, holdTimeout: 0.05)
        coordinator.setHold(true)
        coordinator.setHold(false)

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(engine.applied == [true, false])
    }
}

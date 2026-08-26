import CoreAudio
import Testing

@testable import sotto

/// An in-memory stand-in for a CoreAudio device: every element holds a value,
/// and the test decides which ones exist and accept writes.
private final class FakeDevice: DeviceIO {
    var inputChannelCount: Int
    var present: Set<AudioObjectPropertyElement>
    var settable: Set<AudioObjectPropertyElement>
    var mute: [AudioObjectPropertyElement: UInt32] = [:]
    var volume: [AudioObjectPropertyElement: Float32] = [:]
    var writeFails = false

    init(
        inputChannelCount: Int = 2,
        present: Set<AudioObjectPropertyElement> = [kAudioObjectPropertyElementMain],
        settable: Set<AudioObjectPropertyElement> = [kAudioObjectPropertyElementMain]
    ) {
        self.inputChannelCount = inputChannelCount
        self.present = present
        self.settable = settable
    }

    func has(_ address: AudioObjectPropertyAddress) -> Bool { present.contains(address.mElement) }
    func isSettable(_ address: AudioObjectPropertyAddress) -> Bool { settable.contains(address.mElement) }

    func readUInt32(_ address: AudioObjectPropertyAddress) -> UInt32? { mute[address.mElement] }
    func readFloat(_ address: AudioObjectPropertyAddress) -> Float32? { volume[address.mElement] }

    func writeUInt32(_ value: UInt32, to address: AudioObjectPropertyAddress) throws {
        if writeFails { throw AudioError.unsupported }
        mute[address.mElement] = value
    }

    func writeFloat(_ value: Float32, to address: AudioObjectPropertyAddress) throws {
        if writeFails { throw AudioError.unsupported }
        volume[address.mElement] = value
    }
}

private let main = kAudioObjectPropertyElementMain

@Suite("MutePropertyStrategy")
struct MutePropertyStrategyTests {

    @Test func isUnavailableWhenNothingIsSettable() {
        let device = FakeDevice(present: [], settable: [])
        #expect(MutePropertyStrategy.make(for: device) == nil)
    }

    @Test func writesEveryElementItOwns() throws {
        let device = FakeDevice(present: [1, 2], settable: [1, 2])
        let strategy = try #require(MutePropertyStrategy.make(for: device))

        try strategy.apply(true, to: device)
        #expect(device.mute == [1: 1, 2: 1])

        try strategy.apply(false, to: device)
        #expect(device.mute == [1: 0, 2: 0])
    }

    /// Half-muted is not muted — otherwise the UI claims silence while one
    /// channel is still live.
    @Test func countsAsMutedOnlyWhenEveryElementIs() throws {
        let device = FakeDevice(present: [1, 2], settable: [1, 2])
        let strategy = try #require(MutePropertyStrategy.make(for: device))

        device.mute = [1: 1, 2: 1]
        #expect(strategy.currentlyMuted(on: device) == true)

        device.mute = [1: 1, 2: 0]
        #expect(strategy.currentlyMuted(on: device) == false)
    }

    /// Nothing readable means unknown, which is not the same as unmuted.
    @Test func unreadableDeviceReportsUnknown() throws {
        let device = FakeDevice(present: [1, 2], settable: [1, 2])
        let strategy = try #require(MutePropertyStrategy.make(for: device))
        #expect(strategy.currentlyMuted(on: device) == nil)
    }

    @Test func needsNoWatchdog() throws {
        let strategy = try #require(MutePropertyStrategy.make(for: FakeDevice()))
        #expect(!strategy.needsWatchdog)
        #expect(strategy.name == "mute property")
    }

    @Test func failedWriteIsSurfaced() throws {
        let device = FakeDevice()
        let strategy = try #require(MutePropertyStrategy.make(for: device))
        device.writeFails = true
        #expect(throws: AudioError.self) { try strategy.apply(true, to: device) }
    }
}

@Suite("VolumeScalarStrategy")
struct VolumeScalarStrategyTests {

    @Test func isUnavailableWhenVolumeIsNotSettable() {
        #expect(VolumeScalarStrategy.make(for: FakeDevice(present: [], settable: [])) == nil)
    }

    @Test func mutingDrivesVolumeToZero() throws {
        let device = FakeDevice()
        let strategy = try #require(VolumeScalarStrategy.make(for: device))
        device.volume = [main: 0.8]

        try strategy.apply(true, to: device)
        #expect(device.volume[main] == 0)
    }

    /// The whole point of this strategy: unmuting has to give back the level
    /// the user had, not some default.
    @Test func unmutingRestoresTheSavedLevel() throws {
        let device = FakeDevice()
        let strategy = try #require(VolumeScalarStrategy.make(for: device))
        device.volume = [main: 0.42]

        try strategy.apply(true, to: device)
        try strategy.apply(false, to: device)
        #expect(device.volume[main] == 0.42)
    }

    /// Muting twice must not overwrite the saved level with the zero it just
    /// wrote, or unmute would restore silence.
    @Test func repeatedMuteKeepsTheOriginalLevel() throws {
        let device = FakeDevice()
        let strategy = try #require(VolumeScalarStrategy.make(for: device))
        device.volume = [main: 0.6]

        try strategy.apply(true, to: device)
        try strategy.apply(true, to: device)
        try strategy.apply(false, to: device)
        #expect(device.volume[main] == 0.6)
    }

    /// Unmuting a device that was already silent has nothing to restore, so it
    /// lands on a usable level rather than staying at zero.
    @Test func unmutingWithNothingSavedUsesAMidLevel() throws {
        let device = FakeDevice()
        let strategy = try #require(VolumeScalarStrategy.make(for: device))
        device.volume = [main: 0]

        try strategy.apply(true, to: device)
        try strategy.apply(false, to: device)
        #expect(device.volume[main] == 0.5)
    }

    @Test func mutedMeansExactlyZero() throws {
        let device = FakeDevice()
        let strategy = try #require(VolumeScalarStrategy.make(for: device))

        device.volume = [main: 0]
        #expect(strategy.currentlyMuted(on: device) == true)

        device.volume = [main: 0.01]
        #expect(strategy.currentlyMuted(on: device) == false)
    }

    @Test func unreadableVolumeReportsUnknown() throws {
        let device = FakeDevice()
        let strategy = try #require(VolumeScalarStrategy.make(for: device))
        #expect(strategy.currentlyMuted(on: device) == nil)
    }

    /// Channels can disagree; the loudest one decides, so a single live channel
    /// is never mistaken for silence.
    @Test func loudestChannelDecides() throws {
        let device = FakeDevice(present: [1, 2], settable: [1, 2])
        let strategy = try #require(VolumeScalarStrategy.make(for: device))
        device.volume = [1: 0, 2: 0.7]

        #expect(strategy.readVolume(on: device) == 0.7)
        #expect(strategy.currentlyMuted(on: device) == false)
    }

    @Test func writesEveryElementItOwns() throws {
        let device = FakeDevice(present: [1, 2], settable: [1, 2])
        let strategy = try #require(VolumeScalarStrategy.make(for: device))
        device.volume = [1: 0.3, 2: 0.9]

        try strategy.apply(true, to: device)
        #expect(device.volume == [1: 0, 2: 0])
    }

    /// Zeroing the volume is not sticky the way a mute property is, so the
    /// controller has to keep watching it.
    @Test func needsAWatchdog() throws {
        let strategy = try #require(VolumeScalarStrategy.make(for: FakeDevice()))
        #expect(strategy.needsWatchdog)
        #expect(strategy.name == "volume scalar")
    }
}

@Suite("MuteStrategyFactory")
struct MuteStrategyFactoryTests {

    private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioDevice.address(selector, element: main)
    }

    /// A real mute property is preferred; driving volume to zero is the
    /// fallback because it is lossy and needs a watchdog.
    @Test func prefersTheMuteProperty() {
        let device = FakeDevice()
        let strategy = MuteStrategyFactory.strategy(for: device)
        #expect(strategy is MutePropertyStrategy)
    }

    @Test func fallsBackToVolumeWhenMuteIsMissing() {
        final class VolumeOnlyDevice: DeviceIO {
            var inputChannelCount = 2
            var volume: [AudioObjectPropertyElement: Float32] = [:]

            func has(_ address: AudioObjectPropertyAddress) -> Bool {
                address.mSelector == kAudioDevicePropertyVolumeScalar && address.mElement == main
            }
            func isSettable(_ address: AudioObjectPropertyAddress) -> Bool { has(address) }
            func readUInt32(_ address: AudioObjectPropertyAddress) -> UInt32? { nil }
            func readFloat(_ address: AudioObjectPropertyAddress) -> Float32? { volume[address.mElement] }
            func writeUInt32(_ value: UInt32, to address: AudioObjectPropertyAddress) throws {}
            func writeFloat(_ value: Float32, to address: AudioObjectPropertyAddress) throws {
                volume[address.mElement] = value
            }
        }
        #expect(MuteStrategyFactory.strategy(for: VolumeOnlyDevice()) is VolumeScalarStrategy)
    }

    @Test func noStrategyForADeviceThatExposesNeither() {
        #expect(MuteStrategyFactory.strategy(for: FakeDevice(present: [], settable: [])) == nil)
    }
}

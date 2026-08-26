import CoreAudio
import Testing

@testable import sotto

/// A device that exposes exactly the elements a test says it does.
private struct FakeDevice: DeviceQuerying {
    var inputChannelCount: Int
    var present: Set<AudioObjectPropertyElement> = []
    var settable: Set<AudioObjectPropertyElement> = []

    func has(_ address: AudioObjectPropertyAddress) -> Bool {
        present.contains(address.mElement)
    }

    func isSettable(_ address: AudioObjectPropertyAddress) -> Bool {
        settable.contains(address.mElement)
    }
}

@Suite("PropertySupport")
struct PropertySupportTests {
    private let selector = kAudioDevicePropertyMute
    private let main = kAudioObjectPropertyElementMain

    private func elements(_ device: FakeDevice) -> [AudioObjectPropertyElement] {
        PropertySupport.settableElements(selector, on: device)
    }

    @Test func mainWinsWhenItIsSettable() {
        let device = FakeDevice(inputChannelCount: 2, present: [main, 1, 2], settable: [main, 1, 2])
        #expect(elements(device) == [main])
    }

    /// Some devices advertise mute on main but refuse writes; the channels are
    /// the fallback, not an error.
    @Test func readOnlyMainFallsBackToChannels() {
        let device = FakeDevice(inputChannelCount: 2, present: [main, 1, 2], settable: [1, 2])
        #expect(elements(device) == [1, 2])
    }

    @Test func absentMainFallsBackToChannels() {
        let device = FakeDevice(inputChannelCount: 2, present: [1, 2], settable: [main, 1, 2])
        #expect(elements(device) == [1, 2])
    }

    @Test func onlySettableChannelsAreReturned() {
        let device = FakeDevice(inputChannelCount: 4, present: [1, 2, 3, 4], settable: [2, 4])
        #expect(elements(device) == [2, 4])
    }

    /// A channel has to be both present and settable — advertising one without
    /// the other means a silent no-op write.
    @Test func presentButUnsettableChannelIsSkipped() {
        let device = FakeDevice(inputChannelCount: 2, present: [1, 2], settable: [1])
        #expect(elements(device) == [1])
    }

    @Test func nothingSettableYieldsNoElements() {
        let device = FakeDevice(inputChannelCount: 2, present: [main, 1, 2], settable: [])
        #expect(elements(device).isEmpty)
    }

    /// A mono device still gets channels 1 and 2 probed, because the channel
    /// count is not always honest about what carries the mute property.
    @Test func monoDeviceStillProbesTwoChannels() {
        let device = FakeDevice(inputChannelCount: 1, present: [1, 2], settable: [1, 2])
        #expect(elements(device) == [1, 2])
    }

    @Test func zeroChannelDeviceStillProbesTwoChannels() {
        let device = FakeDevice(inputChannelCount: 0, present: [2], settable: [2])
        #expect(elements(device) == [2])
    }

    @Test func multiChannelDeviceProbesEveryChannel() {
        let device = FakeDevice(inputChannelCount: 6, present: [6], settable: [6])
        #expect(elements(device) == [6])
    }

    /// Main is element 0; it must never be probed as if it were a channel.
    @Test func mainIsNotProbedAsAChannel() {
        let device = FakeDevice(inputChannelCount: 2, present: [main], settable: [main])
        #expect(elements(device) == [main])

        let unsettableMain = FakeDevice(inputChannelCount: 2, present: [main], settable: [])
        #expect(unsettableMain.has(AudioDevice.address(kAudioDevicePropertyMute, element: main)))
        #expect(elements(unsettableMain).isEmpty)
    }
}

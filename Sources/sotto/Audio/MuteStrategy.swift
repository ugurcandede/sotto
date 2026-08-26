import CoreAudio
import Foundation

/// How a given device is muted. Chosen per device at runtime — not every
/// device exposes a settable mute property.
protocol MuteStrategy: AnyObject {
    var name: String { get }
    var needsWatchdog: Bool { get }
    var elements: [AudioObjectPropertyElement] { get }

    func apply(_ muted: Bool, to device: DeviceIO) throws
    func currentlyMuted(on device: DeviceIO) -> Bool?
}

/// The parts of a device `PropertySupport` interrogates. Splitting it out lets
/// the element-picking rule be tested without CoreAudio hardware.
protocol DeviceQuerying {
    var inputChannelCount: Int { get }

    func has(_ address: AudioObjectPropertyAddress) -> Bool
    func isSettable(_ address: AudioObjectPropertyAddress) -> Bool
}

/// The reads and writes the strategies perform. A generic `read`/`write` pair
/// cannot cross a protocol boundary without making every strategy generic, so
/// the two concrete types they actually use are spelled out here.
protocol DeviceIO: DeviceQuerying {
    func readUInt32(_ address: AudioObjectPropertyAddress) -> UInt32?
    func readFloat(_ address: AudioObjectPropertyAddress) -> Float32?
    func writeUInt32(_ value: UInt32, to address: AudioObjectPropertyAddress) throws
    func writeFloat(_ value: Float32, to address: AudioObjectPropertyAddress) throws
}

extension AudioDevice: DeviceIO {
    func readUInt32(_ address: AudioObjectPropertyAddress) -> UInt32? {
        try? read(address, as: UInt32.self)
    }

    func readFloat(_ address: AudioObjectPropertyAddress) -> Float32? {
        try? read(address, as: Float32.self)
    }

    func writeUInt32(_ value: UInt32, to address: AudioObjectPropertyAddress) throws {
        try write(value, to: address)
    }

    func writeFloat(_ value: Float32, to address: AudioObjectPropertyAddress) throws {
        try write(value, to: address)
    }
}

enum PropertySupport {
    /// Elements exposing `selector` as settable. Some devices only expose mute
    /// on the channel elements (1, 2) and not on main (0), so main is tried
    /// first and channels are the fallback.
    static func settableElements(_ selector: AudioObjectPropertySelector, on device: DeviceQuerying) -> [AudioObjectPropertyElement] {
        let main = AudioDevice.address(selector, element: kAudioObjectPropertyElementMain)
        if device.has(main), device.isSettable(main) {
            return [kAudioObjectPropertyElementMain]
        }

        let channels = (1...max(device.inputChannelCount, 2)).map(AudioObjectPropertyElement.init)
        return channels.filter { element in
            let address = AudioDevice.address(selector, element: element)
            return device.has(address) && device.isSettable(address)
        }
    }
}

// MARK: - Preferred: the device's own mute property

final class MutePropertyStrategy: MuteStrategy {
    let name = "mute property"
    let needsWatchdog = false
    let elements: [AudioObjectPropertyElement]

    private init(elements: [AudioObjectPropertyElement]) {
        self.elements = elements
    }

    static func make(for device: DeviceIO) -> MutePropertyStrategy? {
        let elements = PropertySupport.settableElements(kAudioDevicePropertyMute, on: device)
        return elements.isEmpty ? nil : MutePropertyStrategy(elements: elements)
    }

    func apply(_ muted: Bool, to device: DeviceIO) throws {
        for element in elements {
            try device.writeUInt32(UInt32(muted ? 1 : 0), to: AudioDevice.address(kAudioDevicePropertyMute, element: element))
        }
    }

    func currentlyMuted(on device: DeviceIO) -> Bool? {
        let values = elements.compactMap {
            device.readUInt32(AudioDevice.address(kAudioDevicePropertyMute, element: $0))
        }
        guard !values.isEmpty else { return nil }
        return values.allSatisfy { $0 != 0 }
    }
}

// MARK: - Fallback: drive input volume to zero

final class VolumeScalarStrategy: MuteStrategy {
    let name = "volume scalar"
    let needsWatchdog = true
    let elements: [AudioObjectPropertyElement]

    private var savedVolume: Float32?

    private init(elements: [AudioObjectPropertyElement]) {
        self.elements = elements
    }

    static func make(for device: DeviceIO) -> VolumeScalarStrategy? {
        let elements = PropertySupport.settableElements(kAudioDevicePropertyVolumeScalar, on: device)
        return elements.isEmpty ? nil : VolumeScalarStrategy(elements: elements)
    }

    func apply(_ muted: Bool, to device: DeviceIO) throws {
        if muted {
            if let current = readVolume(on: device), current > 0 {
                savedVolume = current
            }
            try writeVolume(0, to: device)
        } else {
            try writeVolume(savedVolume ?? 0.5, to: device)
        }
    }

    func currentlyMuted(on device: DeviceIO) -> Bool? {
        guard let volume = readVolume(on: device) else { return nil }
        return volume == 0
    }

    func readVolume(on device: DeviceIO) -> Float32? {
        elements.compactMap {
            device.readFloat(AudioDevice.address(kAudioDevicePropertyVolumeScalar, element: $0))
        }.max()
    }

    private func writeVolume(_ volume: Float32, to device: DeviceIO) throws {
        for element in elements {
            try device.writeFloat(volume, to: AudioDevice.address(kAudioDevicePropertyVolumeScalar, element: element))
        }
    }
}

enum MuteStrategyFactory {
    static func strategy(for device: DeviceIO) -> MuteStrategy? {
        MutePropertyStrategy.make(for: device) ?? VolumeScalarStrategy.make(for: device)
    }
}

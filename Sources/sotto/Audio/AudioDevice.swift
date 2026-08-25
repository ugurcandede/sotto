import CoreAudio
import Foundation

enum AudioError: Error {
    case status(OSStatus)
    case noDevice
    case unsupported
}

/// A CoreAudio input device plus the thin property accessors the rest of the
/// app needs. Nothing here mutates state — writes live in `AudioController`.
struct AudioDevice: Equatable {
    let id: AudioObjectID

    static let systemObject = AudioDevice(id: AudioObjectID(kAudioObjectSystemObject))

    var name: String {
        (try? string(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)) ?? "Unknown Device"
    }

    var uid: String {
        (try? string(kAudioDevicePropertyDeviceUID, scope: kAudioObjectPropertyScopeGlobal)) ?? ""
    }

    var isInput: Bool {
        inputChannelCount > 0 && !isHidden && !isPrivateAggregate
    }

    private var isHidden: Bool {
        let value = try? read(Self.address(kAudioDevicePropertyIsHidden, scope: kAudioObjectPropertyScopeGlobal), as: UInt32.self)
        return (value ?? 0) != 0
    }

    /// CoreAudio spins up throwaway aggregates (`CADefaultDevice…`) whenever an
    /// app captures from the default device. They are not user-selectable and
    /// System Settings hides them too.
    private var isPrivateAggregate: Bool {
        let transport = try? read(Self.address(kAudioDevicePropertyTransportType, scope: kAudioObjectPropertyScopeGlobal), as: UInt32.self)
        guard transport == kAudioDeviceTransportTypeAggregate else { return false }

        if name.hasPrefix("CADefaultDevice") { return true }

        let composition = try? read(
            Self.address(kAudioAggregateDevicePropertyComposition, scope: kAudioObjectPropertyScopeGlobal),
            as: CFDictionary.self
        )
        guard let dictionary = composition as? [String: Any] else { return false }
        return (dictionary[kAudioAggregateDeviceIsPrivateKey] as? Int ?? 0) != 0
    }

    /// Channel count on the input scope, from the stream configuration.
    var inputChannelCount: Int {
        var address = Self.address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffer) == noErr else { return 0 }

        let list = UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    // MARK: - Property access

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeInput,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    func has(_ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(id, &address)
    }

    func isSettable(_ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(id, &address, &settable) == noErr else { return false }
        return settable.boolValue
    }

    func read<T>(_ address: AudioObjectPropertyAddress, as type: T.Type) throws -> T {
        var address = address
        var size = UInt32(MemoryLayout<T>.size)
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { buffer.deallocate() }

        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffer)
        guard status == noErr else { throw AudioError.status(status) }
        return buffer.pointee
    }

    func write<T>(_ value: T, to address: AudioObjectPropertyAddress) throws {
        var address = address
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { buffer.deallocate() }
        buffer.initialize(to: value)

        let status = AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<T>.size), buffer)
        guard status == noErr else { throw AudioError.status(status) }
    }

    private func string(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) throws -> String {
        let cfString = try read(Self.address(selector, scope: scope), as: CFString.self)
        return cfString as String
    }

    // MARK: - Discovery

    static var defaultInput: AudioDevice? {
        let address = Self.address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        guard let id = try? systemObject.read(address, as: AudioObjectID.self), id != kAudioObjectUnknown else {
            return nil
        }
        return AudioDevice(id: id)
    }

    static func makeDefaultInput(_ device: AudioDevice) throws {
        try systemObject.write(
            device.id,
            to: address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        )
    }

    static var allInputs: [AudioDevice] {
        var address = Self.address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject.id, &address, 0, nil, &size) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(systemObject.id, &address, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.map(AudioDevice.init(id:)).filter(\.isInput)
    }
}

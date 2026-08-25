import CoreAudio
import Foundation

/// Watches the system default input device and any property on the currently
/// selected device. Listener blocks are removed on `stop()` — leaving them
/// attached to a vanished device is what makes mute state go stale.
final class DeviceObserver {
    private var registrations: [(id: AudioObjectID, address: AudioObjectPropertyAddress, block: AudioObjectPropertyListenerBlock)] = []

    func observe(_ address: AudioObjectPropertyAddress, on id: AudioObjectID, handler: @escaping () -> Void) {
        var address = address
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        guard AudioObjectAddPropertyListenerBlock(id, &address, DispatchQueue.main, block) == noErr else { return }
        registrations.append((id, address, block))
    }

    func stop() {
        for registration in registrations {
            var address = registration.address
            AudioObjectRemovePropertyListenerBlock(registration.id, &address, DispatchQueue.main, registration.block)
        }
        registrations.removeAll()
    }

    deinit { stop() }
}

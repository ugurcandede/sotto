import Foundation
import IOKit.hidsystem

/// Takes over the microphone key (F5 on Apple keyboards) by remapping it at the
/// HID layer, below the point where macOS turns it into a Dictation trigger.
/// Setting `UserKeyMapping` needs no permission, which is why this path is
/// preferred over an event tap.
enum DictationKey {
    /// Consumer page usage 0xCF — "Voice Command", what the mic key sends.
    static let source = 0xC000000CF
    /// F13: nothing on an Apple keyboard emits it, so it is safe to claim.
    static let destination = 0x700000068
    static let keyCode: UInt16 = 105
    static var combo: KeyCombo { KeyCombo(keyCode: keyCode, modifiers: 0) }

    static var isMapped: Bool {
        currentMappings.contains { $0["HIDKeyboardModifierMappingSrc"] == source }
    }

    static func map() {
        var mappings = currentMappings.filter { $0["HIDKeyboardModifierMappingSrc"] != source }
        mappings.append([
            "HIDKeyboardModifierMappingSrc": source,
            "HIDKeyboardModifierMappingDst": destination,
        ])
        write(mappings)
    }

    static func unmap() {
        write(currentMappings.filter { $0["HIDKeyboardModifierMappingSrc"] != source })
    }

    // MARK: - UserKeyMapping

    /// Not `hidutil`: macOS 27 changed `property --get` to print a per-service
    /// table instead of a plist.
    private static let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    private static let key = "UserKeyMapping" as CFString

    /// Other tools use the same mapping table, so read-modify-write rather than
    /// clobbering whatever is already there.
    private static var currentMappings: [[String: Int]] {
        guard let list = IOHIDEventSystemClientCopyProperty(client, key) as? [[String: Any]] else { return [] }

        return list.compactMap { entry in
            guard let src = (entry["HIDKeyboardModifierMappingSrc"] as? NSNumber)?.intValue,
                  let dst = (entry["HIDKeyboardModifierMappingDst"] as? NSNumber)?.intValue
            else { return nil }
            return ["HIDKeyboardModifierMappingSrc": src, "HIDKeyboardModifierMappingDst": dst]
        }
    }

    private static func write(_ mappings: [[String: Int]]) {
        IOHIDEventSystemClientSetProperty(client, key, mappings as CFArray)
    }
}

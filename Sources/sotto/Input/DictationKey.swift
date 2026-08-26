import Foundation

/// Takes over the microphone key (F5 on Apple keyboards) by remapping it at the
/// HID layer, below the point where macOS turns it into a Dictation trigger.
/// `hidutil` needs no permission, which is why this path is preferred over an
/// event tap.
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

    // MARK: - hidutil

    /// Other tools use the same mapping table, so read-modify-write rather than
    /// clobbering whatever is already there.
    private static var currentMappings: [[String: Int]] {
        guard let output = run(["property", "--get", "UserKeyMapping"]),
              let list = (output as NSString).propertyList() as? [[String: Any]]
        else { return [] }

        return list.compactMap { entry in
            guard let src = (entry["HIDKeyboardModifierMappingSrc"] as? NSNumber)?.intValue,
                  let dst = (entry["HIDKeyboardModifierMappingDst"] as? NSNumber)?.intValue
            else { return nil }
            return ["HIDKeyboardModifierMappingSrc": src, "HIDKeyboardModifierMappingDst": dst]
        }
    }

    private static func write(_ mappings: [[String: Int]]) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["UserKeyMapping": mappings]),
              let json = String(data: data, encoding: .utf8)
        else { return }
        _ = run(["property", "--set", json])
    }

    @discardableResult
    private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}

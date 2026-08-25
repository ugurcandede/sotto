import CoreAudio
import Foundation

/// `sotto probe` — prints what each input device actually exposes. The
/// support matrix in the README is generated from this output.
enum ProbeCommand {
    private static let elements: [(label: String, element: AudioObjectPropertyElement)] = [
        ("main", kAudioObjectPropertyElementMain),
        ("ch1", 1),
        ("ch2", 2),
    ]

    static func run() {
        let defaultInput = AudioDevice.defaultInput
        let devices = AudioDevice.allInputs

        guard !devices.isEmpty else {
            print("No input devices found.")
            return
        }

        for device in devices {
            let marker = device == defaultInput ? "  ← default input" : ""
            print("\(device.name)\(marker)")
            print("  uid: \(device.uid)   channels: \(device.inputChannelCount)")
            print("  property         element  exists  settable")

            for selector in [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] {
                let title = selector == kAudioDevicePropertyMute ? "mute" : "volume"
                for (label, element) in elements {
                    let address = AudioDevice.address(selector, element: element)
                    let row = "  " + pad(title, 17) + pad(label, 9) + pad(device.has(address) ? "yes" : "no", 8)
                        + (device.isSettable(address) ? "yes" : "no")
                    print(row)
                }
            }

            print("  VERDICT: \(verdict(for: device))")
            print("")
        }
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.padding(toLength: max(width, text.count + 1), withPad: " ", startingAt: 0)
    }

    private static func verdict(for device: AudioDevice) -> String {
        guard let strategy = MuteStrategyFactory.strategy(for: device) else {
            return "unsupported — no settable mute or volume property"
        }
        let elements = strategy.elements.map { $0 == kAudioObjectPropertyElementMain ? "main" : "ch\($0)" }
        let watchdog = strategy.needsWatchdog ? ", watchdog on" : ""
        return "\(strategy.name) on \(elements.joined(separator: "+"))\(watchdog)"
    }
}

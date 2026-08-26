import AVFoundation
import Combine

/// Short-lived input level measurement for the "Test" button. Capturing audio
/// is what lights the orange privacy indicator, so it runs only on demand and
/// stops itself.
@MainActor
final class LevelMeter: ObservableObject {
    @Published private(set) var level: Float = 0
    @Published private(set) var isRunning = false
    @Published private(set) var accessDenied = false

    private var engine: AVAudioEngine?
    private var stopItem: DispatchWorkItem?

    func start(duration: TimeInterval = 5) {
        guard !isRunning else {
            stop()
            return
        }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.accessDenied = !granted
                guard granted else { return }
                self.run(duration: duration)
            }
        }
    }

    func stop() {
        stopItem?.cancel()
        stopItem = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isRunning = false
        level = 0
    }

    private func run(duration: TimeInterval) {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let value = LevelMeter.normalizedLevel(buffer)
            Task { @MainActor in self?.level = value }
        }

        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return
        }

        self.engine = engine
        isRunning = true

        let item = DispatchWorkItem { [weak self] in self?.stop() }
        stopItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    nonisolated static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<count {
            sum += channel[index] * channel[index]
        }
        let rms = sqrt(sum / Float(count))
        let decibels = 20 * log10(max(rms, .leastNormalMagnitude))

        // -60 dB reads as silence, 0 dB as full scale.
        return min(max((decibels + 60) / 60, 0), 1)
    }
}

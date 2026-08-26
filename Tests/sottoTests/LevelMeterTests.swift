import AVFoundation
import Testing

@testable import sotto

@Suite("LevelMeter")
struct LevelMeterTests {

    private func buffer(constant value: Float, frames: Int = 512) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let channel = buffer.floatChannelData![0]
        for index in 0..<frames { channel[index] = value }
        return buffer
    }

    @Test func silenceReadsAsZero() {
        #expect(LevelMeter.normalizedLevel(buffer(constant: 0)) == 0)
    }

    @Test func fullScaleReadsAsOne() {
        #expect(LevelMeter.normalizedLevel(buffer(constant: 1)) == 1)
    }

    /// -60 dB is the floor of the meter's range.
    @Test func minusSixtyDecibelsIsTheFloor() {
        let level = LevelMeter.normalizedLevel(buffer(constant: 0.001))
        #expect(abs(level - 0) < 0.001)
    }

    @Test func minusThirtyDecibelsSitsMidScale() {
        let level = LevelMeter.normalizedLevel(buffer(constant: 0.0316227766))
        #expect(abs(level - 0.5) < 0.001)
    }

    @Test func quieterThanTheFloorClampsToZero() {
        #expect(LevelMeter.normalizedLevel(buffer(constant: 0.0000001)) == 0)
    }

    @Test func emptyBufferReadsAsZero() {
        let empty = buffer(constant: 1, frames: 512)
        empty.frameLength = 0
        #expect(LevelMeter.normalizedLevel(empty) == 0)
    }

    /// Sign must not matter — the meter is RMS, not peak-signed.
    @Test func negativeSamplesReadTheSameAsPositive() {
        let positive = LevelMeter.normalizedLevel(buffer(constant: 0.5))
        let negative = LevelMeter.normalizedLevel(buffer(constant: -0.5))
        #expect(positive == negative)
    }
}

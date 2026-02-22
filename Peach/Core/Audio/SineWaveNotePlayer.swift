import AVFoundation
import AVFAudio
import Foundation
import os

/// A NotePlayer implementation that generates sine wave tones using AVAudioEngine.
///
/// This player produces clean, precisely tuned sine waves suitable for pitch discrimination
/// training. It uses AVAudioPlayerNode to play pre-generated buffers, ensuring precise
/// timing and envelope shaping.
@MainActor
public final class SineWaveNotePlayer: NotePlayer {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SineWaveNotePlayer")

    // MARK: - Audio Components

    private let engine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let format: AVAudioFormat

    // MARK: - State

    private var isSessionConfigured = false

    // MARK: - Constants

    // Human audible frequency range: 20 Hz to 20 kHz
    private static let validFrequencyRange = 20.0...20000.0
    private static let sampleRate: Double = 44100.0
    private static let attackDuration: TimeInterval = 0.005  // 5ms
    private static let releaseDuration: TimeInterval = 0.005 // 5ms

    // MARK: - Initialization

    public init() throws {
        // Create audio format (standard 44.1kHz mono)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: Self.sampleRate,
            channels: 1
        ) else {
            throw AudioError.contextUnavailable
        }
        self.format = format

        // Create audio engine and player node
        self.engine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()

        // Attach and connect player node
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    nonisolated deinit {
        // Clean up audio engine when player is deallocated
        // Note: deinit cannot access MainActor-isolated properties in Swift 6
        // Engine cleanup happens automatically when deallocated
    }

    // MARK: - NotePlayer Protocol

    public func play(frequency: Double, duration: TimeInterval, amplitude: Double = 0.5) async throws {
        // Validate frequency
        guard Self.validFrequencyRange.contains(frequency) else {
            throw AudioError.invalidFrequency(
                "Frequency \(frequency) Hz is outside valid range \(Self.validFrequencyRange)"
            )
        }

        // Validate duration
        guard duration > 0 else {
            throw AudioError.invalidFrequency(
                "Duration \(duration) seconds must be positive"
            )
        }

        // Validate amplitude
        guard (0.0...1.0).contains(amplitude) else {
            throw AudioError.invalidFrequency(
                "Amplitude \(amplitude) is outside valid range 0.0-1.0"
            )
        }

        // Configure audio session once
        if !isSessionConfigured {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            isSessionConfigured = true
        }

        // Start engine if not already running
        if !engine.isRunning {
            try engine.start()
        }

        // Generate audio buffer with sine wave and envelope
        let buffer = try generateBuffer(frequency: frequency, duration: duration, amplitude: amplitude)

        // Play buffer and wait for completion
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Schedule buffer with completion handler
            playerNode.scheduleBuffer(buffer) {
                continuation.resume()
            }

            // Start player if not playing
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }

    public func stop() async throws {
        logger.info("SineWaveNotePlayer.stop() called - stopping audio")
        // Mute the player node, then wait for the volume change to propagate through
        // the audio render thread before stopping. This prevents the click/pop caused
        // by abruptly truncating the waveform at a non-zero sample.
        // Uses playerNode.volume (AVAudioMixing) rather than mainMixerNode.outputVolume
        // because it targets the mixer input for this specific node.
        // Delay covers 2+ render cycles (512 frames @ 44.1kHz ≈ 11.6ms each).
        playerNode.volume = 0
        try? await Task.sleep(for: .milliseconds(25))
        playerNode.stop()
        playerNode.volume = 1.0
        logger.info("AVAudioPlayerNode stopped")
    }

    // MARK: - Buffer Generation

    /// Generates an audio buffer containing a sine wave at the specified frequency with envelope.
    private func generateBuffer(frequency: Double, duration: TimeInterval, amplitude: Double) throws -> AVAudioPCMBuffer {
        // Calculate buffer length in samples
        let attackSamples = Int(Self.attackDuration * Self.sampleRate)
        let releaseSamples = Int(Self.releaseDuration * Self.sampleRate)
        let totalSamples = Int(duration * Self.sampleRate)
        let sustainSamples = max(0, totalSamples - attackSamples - releaseSamples)

        let frameCount = AVAudioFrameCount(totalSamples)

        // Create buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioError.renderFailed("Failed to create audio buffer")
        }
        buffer.frameLength = frameCount

        // Get pointer to buffer data
        guard let channelData = buffer.floatChannelData else {
            throw AudioError.renderFailed("Failed to access buffer data")
        }
        let samples = channelData[0]

        // Generate sine wave with envelope
        var phase: Double = 0.0
        let phaseIncrement = (2.0 * .pi * frequency) / Self.sampleRate

        for frame in 0..<Int(frameCount) {
            // Calculate envelope
            let envelope: Float
            if frame < attackSamples {
                // Attack: ramp from 0 to 1
                envelope = Float(frame) / Float(attackSamples)
            } else if frame < attackSamples + sustainSamples {
                // Sustain: constant at 1
                envelope = 1.0
            } else {
                // Release: ramp from 1 to 0
                let releaseFrame = frame - (attackSamples + sustainSamples)
                envelope = 1.0 - (Float(releaseFrame) / Float(releaseSamples))
            }

            // Generate sine sample with envelope and amplitude
            samples[frame] = Float(sin(phase)) * envelope * Float(amplitude)

            // Update phase
            phase += phaseIncrement
            if phase >= 2.0 * .pi {
                phase -= 2.0 * .pi
            }
        }

        return buffer
    }
}

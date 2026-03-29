import Testing
import Foundation
@testable import Peach

// @Test(arguments:) is incompatible with default MainActor isolation in Swift 6.2:
// the macro expansion accesses static properties from a nonisolated context, and
// makeLibrary() can't be called outside MainActor. All tests use for loops
// with Issue.record for per-case failure reporting instead.

@Suite("SoundFont Preset Stress Tests",
       .enabled(if: ProcessInfo.processInfo.environment["RUN_STRESS_TESTS"] != nil))
struct SoundFontPresetStressTests {

    // MARK: - Constants

    private static let representativeRawValues: Set<String> = [
        "sf2:0:0",  // Grand Piano
        "sf2:0:1",  // Bright Grand Piano
        "sf2:0:2",  // Electric Piano
        "sf2:0:24", // Nylon Guitar
        "sf2:0:42", // Cello
        "sf2:0:56", // Trumpet
        "sf2:0:73", // Flute
        "sf2:8:80"  // Sine Wave
    ]

    private static let focusRawValues: Set<String> = [
        "sf2:0:0", "sf2:0:42", "sf2:0:73", "sf2:8:80"
    ]

    private static let midiNoteValues: [UInt8] = [21, 36, 48, 60, 69, 84, 96, 108, 127]

    // MARK: - Factory

    private static let testLibrary = TestSoundFont.makeLibrary()

    private func makeLibrary() -> SoundFontLibrary {
        Self.testLibrary
    }

    private func makePlayer(preset: SF2Preset) throws -> SoundFontPlayer {
        let engine = try SoundFontEngine(sf2URL: TestSoundFont.url, audioSessionConfigurator: MockAudioSessionConfigurator())
        return SoundFontPlayer(engine: engine, preset: preset)
    }

    // MARK: - Task 2: Per-Preset Smoke Test

    @Test("Every preset loads and plays a note without crash")
    func presetSmoke() async throws {
        let allPresets = makeLibrary().melodicPresets
        #expect(!allPresets.isEmpty, "SoundFontLibrary discovered no presets")

        for preset in allPresets {
            do {
                let player = try makePlayer(preset: preset)
                let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
                try await Task.sleep(for: .milliseconds(100))
                try await handle.stop()
            } catch {
                Issue.record(
                    "Preset '\(preset.name)' (bank \(preset.bank), program \(preset.program)) failed: \(error)"
                )
            }
        }
    }

    // MARK: - Task 3: MIDI Note Range Sweep

    @Test("Representative presets play across MIDI note range without crash")
    func midiNoteRangeSweep() async throws {
        let presets = makeLibrary().melodicPresets.filter {
            Self.representativeRawValues.contains($0.rawValue)
        }
        #expect(!presets.isEmpty, "No representative presets found")

        for preset in presets {
            let player = try makePlayer(preset: preset)

            for midiNote in Self.midiNoteValues {
                let frequency = TuningSystem.equalTemperament.frequency(
                    for: MIDINote(Int(midiNote)),
                    referencePitch: .concert440
                )
                do {
                    let handle = try await player.play(
                        frequency: frequency, velocity: 63, amplitudeDB: 0.0
                    )
                    try await Task.sleep(for: .milliseconds(100))
                    try await handle.stop()
                } catch {
                    Issue.record(
                        "Preset '\(preset.name)' (bank \(preset.bank), program \(preset.program)) failed at MIDI note \(midiNote): \(error)"
                    )
                }
            }
        }
    }

    // MARK: - Task 4: Duration Variation

    @Test("Varied durations do not crash for focus presets")
    func durationVariation() async throws {
        let presets = makeLibrary().melodicPresets.filter {
            Self.focusRawValues.contains($0.rawValue)
        }
        let durations: [Duration] = [.milliseconds(10), .milliseconds(100), .milliseconds(500)]

        for preset in presets {
            let player = try makePlayer(preset: preset)

            for duration in durations {
                do {
                    try await player.play(
                        frequency: 440.0, duration: duration, velocity: 63, amplitudeDB: 0.0
                    )
                } catch {
                    Issue.record(
                        "Preset '\(preset.name)' (bank \(preset.bank), program \(preset.program)) failed at duration \(duration)s: \(error)"
                    )
                }
            }
        }
    }

    // MARK: - Task 5: Velocity Variation

    @Test("Varied velocities do not crash for focus presets")
    func velocityVariation() async throws {
        let presets = makeLibrary().melodicPresets.filter {
            Self.focusRawValues.contains($0.rawValue)
        }
        let velocities: [MIDIVelocity] = [1, 63, 127]

        for preset in presets {
            let player = try makePlayer(preset: preset)

            for velocity in velocities {
                do {
                    let handle = try await player.play(
                        frequency: 440.0, velocity: velocity, amplitudeDB: 0.0
                    )
                    try await Task.sleep(for: .milliseconds(100))
                    try await handle.stop()
                } catch {
                    Issue.record(
                        "Preset '\(preset.name)' (bank \(preset.bank), program \(preset.program)) failed at velocity \(velocity.rawValue): \(error)"
                    )
                }
            }
        }
    }

    // MARK: - Task 6: Rapid Preset Switching

    @Test("Rapid preset switching creates new player per preset without crash")
    func rapidPresetSwitching() async throws {
        let presets = Array(makeLibrary().melodicPresets.prefix(15))

        for preset in presets {
            let player = try makePlayer(preset: preset)
            let handle = try await player.play(frequency: 440.0, velocity: 63, amplitudeDB: 0.0)
            try await Task.sleep(for: .milliseconds(50))
            try await handle.stop()
        }
    }
}

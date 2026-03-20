import Foundation
import Testing
@testable import Peach

@Suite("SoundFontEngine")
struct SoundFontEngineTests {

    private static let testLibrary = TestSoundFont.makeLibrary()
    private static let defaultSoundSource = SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource)

    private func makeEngine(soundSource: any SoundSourceID = defaultSoundSource) throws -> SoundFontEngine {
        try SoundFontEngine(library: Self.testLibrary, soundSource: soundSource)
    }

    // MARK: - Initialization

    @Test("initializes successfully with valid SF2 library")
    func initializesSuccessfully() async {
        #expect(throws: Never.self) {
            _ = try self.makeEngine()
        }
    }

    @Test("audio engine is running after init")
    func engineRunningAfterInit() async throws {
        let engine = try makeEngine()
        #expect(throws: Never.self) {
            try engine.ensureEngineRunning()
        }
    }

    @Test("fails with missing SF2 file")
    func failsWithMissingSF2() async {
        let badLibrary = SoundFontLibrary(
            sf2URL: URL(fileURLWithPath: "/nonexistent/NonExistent.sf2"),
            defaultPreset: "sf2:0:0"
        )
        #expect(throws: (any Error).self) {
            _ = try SoundFontEngine(library: badLibrary, soundSource: SoundSourceTag(rawValue: "sf2:0:0"))
        }
    }

    // MARK: - Preset Loading

    @Test("loadPreset succeeds for valid preset")
    func loadPresetValid() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 42, bank: 0))
    }

    @Test("loadPreset skips reload when same preset is already loaded")
    func loadPresetSkipsSame() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0))
    }

    @Test("loadPreset loads different preset")
    func loadPresetDifferent() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Strings", program: 6, bank: 8))
    }

    // MARK: - Immediate MIDI Dispatch

    @Test("startNote does not crash")
    func startNoteDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
    }

    @Test("stopNote does not crash")
    func stopNoteDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        engine.stopNote(MIDINote(69))
    }

    @Test("sendPitchBend does not crash")
    func sendPitchBendDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.sendPitchBend(PitchBendValue(10000))
    }

    // MARK: - stopAllNotes

    @Test("stopAllNotes does not crash when no notes are playing")
    func stopAllNotesNoNotes() async throws {
        let engine = try makeEngine()
        await engine.stopAllNotes(stopPropagationDelay: .zero)
    }

    @Test("stopAllNotes with propagation delay restores volume")
    func stopAllNotesRestoresVolume() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        await engine.stopAllNotes(stopPropagationDelay: .milliseconds(25))
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        engine.stopNote(MIDINote(69))
    }

    @Test("stopAllNotes silences a playing note")
    func stopAllNotesSilencesNote() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        await engine.stopAllNotes(stopPropagationDelay: .zero)
    }

    // MARK: - Sampler Access

    @Test("sampler is accessible as read-only property")
    func samplerIsAccessible() async throws {
        let engine = try makeEngine()
        let sampler = engine.sampler
        #expect(sampler === engine.sampler)
    }
}

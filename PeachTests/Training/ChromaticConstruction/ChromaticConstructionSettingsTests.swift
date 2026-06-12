import Testing
import Foundation
@testable import Peach

@Suite("ChromaticConstructionSettings Tests")
struct ChromaticConstructionSettingsTests {

    // MARK: - Ascending

    @Test("Ascending policy: upperAnchor derived as lowerAnchor + semitones")
    func ascendingDerivation() async throws {
        let userSettings = MockUserSettings()
        userSettings.tuningSystem = .equalTemperament
        userSettings.referencePitch = .concert440
        var rng = SeededRNG(seed: 1)
        let settings = try ChromaticConstructionSettings.from(
            userSettings: userSettings,
            outerCents: Cents(700.0),
            lowerAnchor: MIDINote(60),
            directionPolicy: .ascending,
            rng: &rng
        )
        #expect(settings.ladder.lowerAnchor.note == MIDINote(60))
        #expect(settings.ladder.upperAnchor.note == MIDINote(67))
        #expect(settings.ladder.outerCents == Cents(700.0))
        #expect(settings.directionPolicy == .ascending)
        #expect(settings.referencePitch == .concert440)
    }

    // MARK: - Descending (anchors flipped)

    @Test("Descending policy: lowerAnchor stays as user MIDI (start), upperAnchor is destination")
    func descendingDerivation() async throws {
        let userSettings = MockUserSettings()
        userSettings.tuningSystem = .equalTemperament
        userSettings.referencePitch = .concert440
        var rng = SeededRNG(seed: 1)
        let settings = try ChromaticConstructionSettings.from(
            userSettings: userSettings,
            outerCents: Cents(700.0),
            lowerAnchor: MIDINote(60),
            directionPolicy: .descending,
            rng: &rng
        )
        // Per Model A: `lowerAnchor` denotes *start* (not lower pitch). For
        // descending walks the start is higher-pitched.
        #expect(settings.ladder.lowerAnchor.note == MIDINote(60))
        #expect(settings.ladder.upperAnchor.note == MIDINote(53))
        #expect(settings.ladder.outerCents == Cents(-700.0))
        #expect(settings.directionPolicy == .descending)
    }

    // MARK: - Mix policy

    @Test("Mix policy: directionPolicy is preserved as .mix; ladder resolves per RNG")
    func mixPolicyPreservedInSettings() async throws {
        let userSettings = MockUserSettings()
        userSettings.tuningSystem = .equalTemperament
        var rng = SeededRNG(seed: 1)
        let settings = try ChromaticConstructionSettings.from(
            userSettings: userSettings,
            outerCents: Cents(700.0),
            lowerAnchor: MIDINote(60),
            directionPolicy: .mix,
            rng: &rng
        )
        #expect(settings.directionPolicy == .mix)
        // The concrete ladder must be either ascending or descending.
        let isAscending = settings.ladder.outerCents > Cents(0.0)
        let isDescending = settings.ladder.outerCents < Cents(0.0)
        #expect(isAscending || isDescending)
    }

    @Test("Mix policy: different RNG seeds can resolve to different directions")
    func mixPolicyReachesBothDirections() async throws {
        let userSettings = MockUserSettings()
        userSettings.tuningSystem = .equalTemperament

        var seenAscending = false
        var seenDescending = false
        for seed in UInt64(0)..<UInt64(32) {
            var rng = SeededRNG(seed: seed)
            let settings = try ChromaticConstructionSettings.from(
                userSettings: userSettings,
                outerCents: Cents(700.0),
                lowerAnchor: MIDINote(60),
                directionPolicy: .mix,
                rng: &rng
            )
            if settings.ladder.outerCents > Cents(0.0) { seenAscending = true }
            if settings.ladder.outerCents < Cents(0.0) { seenDescending = true }
            if seenAscending && seenDescending { break }
        }
        #expect(seenAscending, "Expected at least one ascending resolution across 32 seeds")
        #expect(seenDescending, "Expected at least one descending resolution across 32 seeds")
    }

    // MARK: - Reference-pitch invariance (Q3-aligned, hidden assumption #9)

    @Test("Reference-pitch invariance: targetCents identical across different referencePitch")
    func referencePitchInvariance() async throws {
        let userSettingsLow = MockUserSettings()
        userSettingsLow.tuningSystem = .equalTemperament
        userSettingsLow.referencePitch = Frequency(415.0) // baroque A

        let userSettingsHigh = MockUserSettings()
        userSettingsHigh.tuningSystem = .equalTemperament
        userSettingsHigh.referencePitch = Frequency(442.0) // modern orchestral A

        var rng1 = SeededRNG(seed: 1)
        let settingsLow = try ChromaticConstructionSettings.from(
            userSettings: userSettingsLow,
            outerCents: Cents(700.0),
            lowerAnchor: MIDINote(60),
            directionPolicy: .ascending,
            rng: &rng1
        )
        var rng2 = SeededRNG(seed: 1)
        let settingsHigh = try ChromaticConstructionSettings.from(
            userSettings: userSettingsHigh,
            outerCents: Cents(700.0),
            lowerAnchor: MIDINote(60),
            directionPolicy: .ascending,
            rng: &rng2
        )

        // The cent math is invariant under referencePitch — only anchor frequencies differ.
        for k in 1...settingsLow.ladder.slotCount {
            #expect(settingsLow.ladder.targetCents(forSlotIndex: k) ==
                    settingsHigh.ladder.targetCents(forSlotIndex: k))
        }
        // Anchor frequencies differ as expected.
        let lowAnchorFreq = settingsLow.ladder.lowerAnchor.frequency(
            in: .equalTemperament,
            referencePitch: settingsLow.referencePitch
        )
        let highAnchorFreq = settingsHigh.ladder.lowerAnchor.frequency(
            in: .equalTemperament,
            referencePitch: settingsHigh.referencePitch
        )
        #expect(lowAnchorFreq != highAnchorFreq)
    }

    // MARK: - Tuning-system gating delegated to Ladder.init

    @Test("Just intonation in userSettings causes Ladder.init to throw")
    func tuningSystemGatingPropagates() async {
        let userSettings = MockUserSettings()
        userSettings.tuningSystem = .justIntonation
        var rng = SeededRNG(seed: 1)
        #expect(throws: ChromaticConstructionError.tuningSystemNotEqualTempered(.justIntonation)) {
            try ChromaticConstructionSettings.from(
                userSettings: userSettings,
                outerCents: Cents(700.0),
                lowerAnchor: MIDINote(60),
                directionPolicy: .ascending,
                rng: &rng
            )
        }
    }
}

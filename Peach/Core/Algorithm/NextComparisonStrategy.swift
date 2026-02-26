import Foundation

/// Protocol for comparison selection strategies in adaptive training
///
/// Defines the contract for algorithms that select the next comparison
/// based on the user's perceptual profile and training settings.
///
/// # Architecture Boundary
///
/// NextComparisonStrategy reads from PitchDiscriminationProfile and TrainingSettings,
/// and returns a Comparison value type. It has no concept of:
/// - Audio playback (NotePlayer's responsibility)
/// - Data persistence (TrainingDataStore's responsibility)
/// - Profile updates (PitchDiscriminationProfile's responsibility)
/// - UI rendering (SwiftUI's responsibility)
///
/// # Usage
///
/// The default implementation (`KazezNoteStrategy`) is injected into ComparisonSession
/// in `PeachApp.swift` (Story 9.1). `AdaptiveNoteStrategy` is retained for future use.
/// ```swift
/// let strategy: NextComparisonStrategy = KazezNoteStrategy()
/// let comparison = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
/// ```
protocol NextComparisonStrategy {
    /// Selects the next comparison based on user's perceptual profile and settings
    ///
    /// Stateless selection - all inputs passed via parameters, output depends only on inputs.
    ///
    /// - Parameters:
    ///   - profile: User's perceptual profile with training statistics
    ///   - settings: Training configuration (note range, difficulty bounds, reference pitch)
    ///   - lastComparison: The most recently completed comparison (nil on first comparison)
    /// - Returns: A Comparison ready to be played by NotePlayer
    func nextComparison(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> Comparison
}

/// Training configuration for comparison selection
///
/// Contains settings that control the adaptive algorithm's behavior.
/// Exposed to users via SettingsScreen (@AppStorage) and read live by ComparisonSession.
///
/// # Defaults
///
/// - Note range: C2 to C6 (MIDI 36-84) — typical vocal/instrument range
/// - Natural/Mechanical: 0.5 — balanced between exploration and weak spot focus
/// - Reference pitch: 440Hz — standard concert pitch (A4)
/// - Difficulty bounds: 0.1 to 100.0 cents — practical human discrimination range
struct TrainingSettings {
    var noteRangeMin: MIDINote
    var noteRangeMax: MIDINote
    var naturalVsMechanical: Double
    var referencePitch: Double
    var minCentDifference: Cents
    var maxCentDifference: Cents

    init(
        noteRangeMin: MIDINote = 36,
        noteRangeMax: MIDINote = 84,
        naturalVsMechanical: Double = 0.5,
        referencePitch: Double = 440.0,
        minCentDifference: Cents = 0.1,
        maxCentDifference: Cents = 100.0
    ) {
        self.noteRangeMin = noteRangeMin
        self.noteRangeMax = noteRangeMax
        self.naturalVsMechanical = naturalVsMechanical
        self.referencePitch = referencePitch
        self.minCentDifference = minCentDifference
        self.maxCentDifference = maxCentDifference
    }

    func isInRange(_ note: MIDINote) -> Bool {
        return note >= noteRangeMin && note <= noteRangeMax
    }
}

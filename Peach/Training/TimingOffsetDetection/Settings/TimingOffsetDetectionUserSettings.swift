import Foundation
import os

protocol TimingOffsetDetectionUserSettings {
    var maxRepetitions: Int { get }
    var offsetNotePosition: OffsetNotePosition { get }
    var selectedPattern: TimingOffsetDetectionPattern { get }
}

final class AppTimingOffsetDetectionUserSettings: TimingOffsetDetectionUserSettings {
    var defaults: UserDefaults = .standard

    private static let logger = Logger(
        subsystem: "com.peach.app",
        category: "AppTimingOffsetDetectionUserSettings"
    )

    /// Reads the configured maximum repetition count, clamping missing or out-of-range
    /// values to ``TimingOffsetDetectionSettingsKeys/defaultMaxRepetitions`` — both
    /// below `1` and above the cap (which is also `defaultMaxRepetitions`, the
    /// rightmost stop on the `DiscreteStopsSlider`). Defence in depth: a corrupted
    /// UserDefaults value (0, negative, `Int.max` from a stale future build, debugger
    /// write) must not produce a crashing `precondition` in
    /// ``TimingOffsetDetectionSettings`` nor underflow the slider's nearest-stop
    /// arithmetic.
    var maxRepetitions: Int {
        guard defaults.object(forKey: TimingOffsetDetectionSettingsKeys.maxRepetitions) != nil else {
            return TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions
        }
        let stored = defaults.integer(forKey: TimingOffsetDetectionSettingsKeys.maxRepetitions)
        guard (1...TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions).contains(stored) else {
            return TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions
        }
        return stored
    }

    /// Resolves the active pattern from the stored id, falling back to
    /// ``TimingOffsetDetectionPatternCatalog/defaultPattern`` when the id is
    /// unknown. The unknown-id path logs a `.warning`; the port is the natural
    /// "what's in storage → what the rest of the code sees" boundary, so the
    /// catalog stays pure (registry-only) and policy (log level, fallback) lives here.
    var selectedPattern: TimingOffsetDetectionPattern {
        let id = defaults.string(forKey: TimingOffsetDetectionSettingsKeys.selectedPatternId)
            ?? TimingOffsetDetectionPatternCatalog.defaultPatternId
        do {
            return try TimingOffsetDetectionPatternCatalog.pattern(withId: id)
        } catch {
            switch error {
            case .unknownPatternId(let unknown):
                Self.logger.warning("Unknown TOD pattern id '\(unknown, privacy: .public)' in UserDefaults; falling back to default pattern")
            }
            return TimingOffsetDetectionPatternCatalog.defaultPattern
        }
    }

    /// Reads the stored 1-based audible position, routing through the active
    /// pattern's ``TimingOffsetDetectionPattern/clampedOffsetNotePosition(_:)``
    /// so the metric-anchor exclusion holds at the storage boundary. Absent
    /// keys return the active pattern's own
    /// ``TimingOffsetDetectionPattern/defaultOffsetNotePosition``.
    var offsetNotePosition: OffsetNotePosition {
        let pattern = selectedPattern
        guard defaults.object(forKey: TimingOffsetDetectionSettingsKeys.offsetNotePosition) != nil else {
            return pattern.defaultOffsetNotePosition
        }
        let stored = defaults.integer(forKey: TimingOffsetDetectionSettingsKeys.offsetNotePosition)
        return pattern.clampedOffsetNotePosition(stored)
    }
}

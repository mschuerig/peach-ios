import Foundation
import SwiftUI
import os

struct TimingOffsetDetectionDiscipline: TrainingDisciplineUI, Sendable {
    private static let logger = Logger(subsystem: "com.peach.app", category: "TimingOffsetDetectionDiscipline")

    let id = TrainingDisciplineID.timingOffsetDetection

    let category: TrainingCategory = .rhythm

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Compare Timing"),
        shortLabel: String(localized: "Compare"),
        systemImageName: "metronome",
        isHero: false,
        helpDescription: String(localized: "Hear a short rhythmic pattern and decide whether the tested note was early or late."),
        unitLabel: String(localized: "ms"),
        optimalBaseline: 15.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] {
        TempoRange.defaultRanges.flatMap { range in
            TimingDirection.allCases.map { direction in
                .rhythm(id, range, direction)
            }
        }
    }

    var helpSections: [HelpSection] { TimingOffsetDetectionHelp.trainingScreen }

    let navigationDestination: NavigationDestination = .timingOffsetDetection

    // MARK: - UI

    /// Renders the same rhythm spectrogram card that ``ContinuousRhythmMatchingDiscipline``
    /// renders; the card is keyed by `mode` so each discipline gets its own
    /// per-mode timeline. Cross-feature reference is intentional and documented:
    /// the card is genuinely shared rhythm-category UI, owned by the
    /// ``ContinuousRhythmMatching`` feature directory by the 77.2 spec.
    var profileCard: AnyView { AnyView(RhythmProfileCardView(mode: id)) }

    /// Declares the rhythm tempo section so this discipline remains
    /// self-contained: tempo configuration is meaningful for timing-offset
    /// training even when ``ContinuousRhythmMatchingDiscipline`` is not
    /// registered. The aggregating screen dedupes by ``DisciplineSettingsSection/id``,
    /// so when both rhythm disciplines are active the section renders once.
    var settingsSections: [DisciplineSettingsSection] {
        [
            DisciplineSettingsSection(id: SharedRhythmSectionID.tempo) { RhythmTempoSettingsSection() },
        ]
    }

    /// Mirrors the rhythm tempo help so disabling
    /// ``ContinuousRhythmMatchingDiscipline`` does not silently strip help
    /// for a setting timing-offset training still consumes. Help aggregation
    /// dedupes by content, so this declaration is a no-op when both rhythm
    /// disciplines are active.
    var settingsHelp: [HelpSection] { ContinuousRhythmMatchingHelp.tempoSettingsHelp }

    /// Mirrors the rhythm spectrogram profile help for the same reason as
    /// ``settingsHelp``: the card this discipline renders is the rhythm
    /// spectrogram, and its help should accompany it whether or not
    /// ``ContinuousRhythmMatchingDiscipline`` is registered.
    var profileHelp: [HelpSection] { ContinuousRhythmMatchingHelp.profileHelp }

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for entry in try store.fetchPayloads(TimingOffsetDetectionPayload.self) {
            let p = entry.payload
            let offset = TimingOffset(.milliseconds(p.offsetMs))
            guard let range = TempoRange.range(for: TempoBPM(p.tempoBPM)) else {
                Self.logger.warning("Skipping record with out-of-range tempoBPM=\(p.tempoBPM) at \(entry.timestamp)")
                continue
            }
            builder.addPoint(
                MetricPoint(timestamp: entry.timestamp, value: abs(p.offsetMs)),
                for: .rhythm(id, range, offset.direction),
                isCorrect: p.isCorrect
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "rhythmOffsetDetection"

    let csvColumns = ["isCorrect", "tempoBPM", "offsetMs"]

    func csvKeyValuePairs(for payload: any TrainingDisciplinePayload) -> [(String, String)] {
        guard let p = payload as? TimingOffsetDetectionPayload else {
            assertionFailure("Expected TimingOffsetDetectionPayload, got \(type(of: payload))")
            return []
        }
        return [
            ("isCorrect", p.isCorrect ? "true" : "false"),
            ("tempoBPM", "\(p.tempoBPM)"),
            ("offsetMs", CSVParserHelpers.formatDouble(p.offsetMs)),
        ]
    }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: any TrainingDisciplinePayload), CSVImportError> {
        guard let timestampIdx = columnIndex["timestamp"],
              let isCorrectIdx = columnIndex["isCorrect"],
              let tempoBPMIdx = columnIndex["tempoBPM"],
              let offsetMsIdx = columnIndex["offsetMs"] else {
            return .failure(.invalidRowData(row: rowNumber, column: "row", value: "", reason: "missing required columns"))
        }

        let timestampStr = fields[timestampIdx]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .failure(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let isCorrectStr = fields[isCorrectIdx]
        guard isCorrectStr == "true" || isCorrectStr == "false" else {
            return .failure(.invalidRowData(row: rowNumber, column: "isCorrect", value: isCorrectStr, reason: "must be 'true' or 'false'"))
        }

        let tempoBPMStr = fields[tempoBPMIdx]
        guard let tempoBPM = Int(tempoBPMStr), tempoBPM > 0 else {
            return .failure(.invalidRowData(row: rowNumber, column: "tempoBPM", value: tempoBPMStr, reason: "must be a positive integer"))
        }

        let offsetMsStr = fields[offsetMsIdx]
        guard let offsetMs = Double(offsetMsStr), offsetMs.isFinite else {
            return .failure(.invalidRowData(row: rowNumber, column: "offsetMs", value: offsetMsStr, reason: "not a valid number"))
        }

        let payload = TimingOffsetDetectionPayload(
            tempoBPM: tempoBPM,
            offsetMs: offsetMs,
            isCorrect: isCorrectStr == "true"
        )
        return .success((timestamp: timestamp, payload: payload))
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] {
        try store.fetchPayloads(TimingOffsetDetectionPayload.self)
            .map { ($0.timestamp, $0.payload) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] {
        parseResult.payloads[csvTrainingType] ?? []
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildRhythmDuplicateKeys(timingOffsetDetectionsIn: store, trainingType: csvTrainingType)
        var imported = 0, skipped = 0
        for entry in parsedRecords(from: parseResult) {
            guard let p = entry.payload as? TimingOffsetDetectionPayload else { continue }
            let key = RhythmDuplicateKey(timestamp: entry.timestamp, tempoBPM: p.tempoBPM, trainingType: csvTrainingType)
            if existingKeys.contains(key) {
                skipped += 1
            } else {
                let envelope = try JSONEnvelope.encode(p, timestamp: entry.timestamp)
                scope.insert(envelope)
                existingKeys.insert(key)
                imported += 1
            }
        }
        return (imported, skipped)
    }
}

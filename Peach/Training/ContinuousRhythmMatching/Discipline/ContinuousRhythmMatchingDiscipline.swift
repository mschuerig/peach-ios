import Foundation
import SwiftUI

struct ContinuousRhythmMatchingDiscipline: TrainingDisciplineUI, Sendable {
    let id = TrainingDisciplineID.continuousRhythmMatching

    let category: TrainingCategory = .rhythm

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Fill the Gap"),
        shortLabel: String(localized: "Fill the Gap"),
        systemImageName: "hand.tap",
        isHero: false,
        helpDescription: String(localized: "A continuous stream of notes plays — tap at the right moment to fill the gap."),
        unitLabel: String(localized: "ms"),
        optimalBaseline: 20.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] {
        TempoRange.defaultRanges.flatMap { range in
            TimingDirection.allCases.map { direction in
                .rhythm(id, range, direction)
            }
        }
    }

    var helpSections: [HelpSection] { ContinuousRhythmMatchingHelp.trainingScreen }

    let navigationDestination: NavigationDestination = .continuousRhythmMatching

    // MARK: - UI

    var profileCard: AnyView { AnyView(RhythmProfileCardView(mode: id)) }

    var settingsSections: [DisciplineSettingsSection] {
        [
            DisciplineSettingsSection(id: SharedRhythmSectionID.tempo) { RhythmTempoSettingsSection() },
            DisciplineSettingsSection(id: SharedRhythmSectionID.gapPositions) { RhythmGapPositionsSettingsSection() },
        ]
    }

    var settingsHelp: [HelpSection] { ContinuousRhythmMatchingHelp.settingsHelp }

    var profileHelp: [HelpSection] { ContinuousRhythmMatchingHelp.profileHelp }

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for entry in try store.fetchPayloads(ContinuousRhythmMatchingPayload.self) {
            let p = entry.payload
            let offset = TimingOffset(.milliseconds(p.meanOffsetMs))
            guard let range = TempoRange.range(for: TempoBPM(p.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: entry.timestamp, value: abs(p.meanOffsetMs)),
                for: .rhythm(id, range, offset.direction)
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "continuousRhythmMatching"

    let csvColumns = [
        "tempoBPM", "meanOffsetMs",
        "meanOffsetMsPosition0", "meanOffsetMsPosition1",
        "meanOffsetMsPosition2", "meanOffsetMsPosition3",
    ]

    func csvKeyValuePairs(for payload: any TrainingDisciplinePayload) -> [(String, String)] {
        guard let p = payload as? ContinuousRhythmMatchingPayload else {
            assertionFailure("Expected ContinuousRhythmMatchingPayload, got \(type(of: payload))")
            return []
        }
        return [
            ("tempoBPM", "\(p.tempoBPM)"),
            ("meanOffsetMs", CSVParserHelpers.formatDouble(p.meanOffsetMs)),
            ("meanOffsetMsPosition0", CSVParserHelpers.formatOptionalDouble(p.meanOffsetMsPosition0)),
            ("meanOffsetMsPosition1", CSVParserHelpers.formatOptionalDouble(p.meanOffsetMsPosition1)),
            ("meanOffsetMsPosition2", CSVParserHelpers.formatOptionalDouble(p.meanOffsetMsPosition2)),
            ("meanOffsetMsPosition3", CSVParserHelpers.formatOptionalDouble(p.meanOffsetMsPosition3)),
        ]
    }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: any TrainingDisciplinePayload), CSVImportError> {
        guard let timestampIdx = columnIndex["timestamp"],
              let tempoBPMIdx = columnIndex["tempoBPM"],
              let meanOffsetMsIdx = columnIndex["meanOffsetMs"] else {
            return .failure(.invalidRowData(row: rowNumber, column: "row", value: "", reason: "missing required columns"))
        }

        let timestampStr = fields[timestampIdx]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .failure(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let tempoBPMStr = fields[tempoBPMIdx]
        guard let tempoBPM = Int(tempoBPMStr), tempoBPM > 0 else {
            return .failure(.invalidRowData(row: rowNumber, column: "tempoBPM", value: tempoBPMStr, reason: "must be a positive integer"))
        }

        let meanOffsetMsStr = fields[meanOffsetMsIdx]
        guard let meanOffsetMs = Double(meanOffsetMsStr), meanOffsetMs.isFinite else {
            return .failure(.invalidRowData(row: rowNumber, column: "meanOffsetMs", value: meanOffsetMsStr, reason: "not a valid number"))
        }

        let positionColumns = ["meanOffsetMsPosition0", "meanOffsetMsPosition1", "meanOffsetMsPosition2", "meanOffsetMsPosition3"]
        var positionValues: [Double?] = []
        for columnName in positionColumns {
            guard let idx = columnIndex[columnName] else {
                positionValues.append(nil)
                continue
            }
            let str = fields[idx]
            if str.isEmpty {
                positionValues.append(nil)
            } else if let value = Double(str), value.isFinite {
                positionValues.append(value)
            } else {
                return .failure(.invalidRowData(row: rowNumber, column: columnName, value: str, reason: "not a valid number"))
            }
        }

        let payload = ContinuousRhythmMatchingPayload(
            tempoBPM: tempoBPM,
            meanOffsetMs: meanOffsetMs,
            meanOffsetMsPosition0: positionValues[0],
            meanOffsetMsPosition1: positionValues[1],
            meanOffsetMsPosition2: positionValues[2],
            meanOffsetMsPosition3: positionValues[3]
        )
        return .success((timestamp: timestamp, payload: payload))
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] {
        try store.fetchPayloads(ContinuousRhythmMatchingPayload.self)
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
        var existingKeys = try buildRhythmDuplicateKeys(from: store)
        var imported = 0, skipped = 0
        for entry in parsedRecords(from: parseResult) {
            guard let p = entry.payload as? ContinuousRhythmMatchingPayload else { continue }
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

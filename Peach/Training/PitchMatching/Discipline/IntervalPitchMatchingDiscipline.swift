import Foundation

struct IntervalPitchMatchingDiscipline: TrainingDisciplineUI, Sendable {
    let id = TrainingDisciplineID.intervalPitchMatching

    let category: TrainingCategory = .intervals

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Match Intervals"),
        shortLabel: String(localized: "Match"),
        systemImageName: "target",
        isHero: false,
        helpDescription: String(localized: "Match pitches using musical intervals."),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 8.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    var helpSections: [HelpSection] { PitchMatchingHelp.trainingScreen }

    let navigationDestination: NavigationDestination = .pitchMatching(isIntervalMode: true)

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for entry in try store.fetchPayloads(PitchMatchingPayload.self) where entry.payload.interval != 0 {
            builder.addPoint(
                MetricPoint(timestamp: entry.timestamp, value: abs(entry.payload.userCentError)),
                for: .pitch(id)
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "pitchMatching"

    let csvColumns = [
        "referenceNote", "referenceNoteName", "targetNote", "targetNoteName",
        "interval", "tuningSystem", "initialCentOffset", "userCentError",
    ]

    func csvKeyValuePairs(for payload: any TrainingDisciplinePayload) -> [(String, String)] {
        guard let p = payload as? PitchMatchingPayload else {
            assertionFailure("Expected PitchMatchingPayload, got \(type(of: payload))")
            return []
        }
        return [
            ("referenceNote", "\(p.referenceNote)"),
            ("referenceNoteName", CSVParserHelpers.formatNoteName(p.referenceNote)),
            ("targetNote", "\(p.targetNote)"),
            ("targetNoteName", CSVParserHelpers.formatNoteName(p.targetNote)),
            ("interval", CSVParserHelpers.formatInterval(p.interval)),
            ("tuningSystem", p.tuningSystem),
            ("initialCentOffset", CSVParserHelpers.formatDouble(p.initialCentOffset)),
            ("userCentError", CSVParserHelpers.formatDouble(p.userCentError)),
        ]
    }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: any TrainingDisciplinePayload), CSVImportError> {
        PitchMatchingCSVParser.parse(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] {
        try store.fetchPayloads(PitchMatchingPayload.self)
            .filter { $0.payload.interval != 0 }
            .map { ($0.timestamp, $0.payload) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] {
        (parseResult.payloads[csvTrainingType] ?? [])
            .filter { ($0.payload as? PitchMatchingPayload)?.interval != 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildPitchDuplicateKeys(from: store)
        var imported = 0, skipped = 0
        for entry in parsedRecords(from: parseResult) {
            guard let p = entry.payload as? PitchMatchingPayload else { continue }
            let key = PitchDuplicateKey(timestamp: entry.timestamp, payload: p)
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

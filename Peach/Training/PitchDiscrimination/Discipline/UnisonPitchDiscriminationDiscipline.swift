import Foundation

struct UnisonPitchDiscriminationDiscipline: TrainingDisciplineUI, Sendable {
    let id = TrainingDisciplineID.unisonPitchDiscrimination

    let category: TrainingCategory = .pitch

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Compare Pitch"),
        shortLabel: String(localized: "Compare"),
        systemImageName: "ear",
        isHero: true,
        helpDescription: String(localized: "Listen to two notes and decide which one is higher."),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 8.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    var helpSections: [HelpSection] { PitchDiscriminationHelp.trainingScreen }

    let navigationDestination: NavigationDestination = .pitchDiscrimination(isIntervalMode: false)

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for entry in try store.fetchPayloads(PitchDiscriminationPayload.self) where entry.payload.interval == 0 {
            builder.addPoint(
                MetricPoint(timestamp: entry.timestamp, value: abs(entry.payload.centOffset)),
                for: .pitch(id),
                isCorrect: entry.payload.isCorrect
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "pitchDiscrimination"

    let csvColumns = [
        "referenceNote", "referenceNoteName", "targetNote", "targetNoteName",
        "interval", "tuningSystem", "centOffset", "isCorrect",
    ]

    func csvKeyValuePairs(for payload: any TrainingDisciplinePayload) -> [(String, String)] {
        guard let p = payload as? PitchDiscriminationPayload else {
            assertionFailure("Expected PitchDiscriminationPayload, got \(type(of: payload))")
            return []
        }
        return [
            ("referenceNote", "\(p.referenceNote)"),
            ("referenceNoteName", CSVParserHelpers.formatNoteName(p.referenceNote)),
            ("targetNote", "\(p.targetNote)"),
            ("targetNoteName", CSVParserHelpers.formatNoteName(p.targetNote)),
            ("interval", CSVParserHelpers.formatInterval(p.interval)),
            ("tuningSystem", p.tuningSystem),
            ("centOffset", CSVParserHelpers.formatDouble(p.centOffset)),
            ("isCorrect", p.isCorrect ? "true" : "false"),
        ]
    }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: any TrainingDisciplinePayload), CSVImportError> {
        PitchDiscriminationCSVParser.parse(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] {
        try store.fetchPayloads(PitchDiscriminationPayload.self)
            .filter { $0.payload.interval == 0 }
            .map { ($0.timestamp, $0.payload) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] {
        (parseResult.payloads[csvTrainingType] ?? [])
            .filter { ($0.payload as? PitchDiscriminationPayload)?.interval == 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildPitchDuplicateKeys(discriminationsIn: store, trainingType: csvTrainingType)
        var imported = 0, skipped = 0
        for entry in parsedRecords(from: parseResult) {
            guard let p = entry.payload as? PitchDiscriminationPayload else { continue }
            let key = PitchDuplicateKey(timestamp: entry.timestamp, payload: p, trainingType: csvTrainingType)
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

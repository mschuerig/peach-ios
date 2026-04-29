import Foundation

struct IntervalPitchDiscriminationDiscipline: TrainingDisciplineUI, Sendable {
    let id = TrainingDisciplineID.intervalPitchDiscrimination

    let category: TrainingCategory = .intervals

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Compare Intervals"),
        shortLabel: String(localized: "Compare"),
        systemImageName: "ear",
        isHero: false,
        helpDescription: String(localized: "The same idea, but with musical intervals between notes."),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 12.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    var helpSections: [HelpSection] { PitchDiscriminationHelp.trainingScreen }

    let navigationDestination: NavigationDestination = .pitchDiscrimination(isIntervalMode: true)

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for entry in try store.fetchPayloads(PitchDiscriminationPayload.self) where entry.payload.interval != 0 {
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

    var csvHistory: CSVHistory { PitchDiscriminationCSVHistory.history }

    func csvKeyValuePairs(for payload: PitchDiscriminationPayload) -> [(String, String)] {
        [
            ("referenceNote", "\(payload.referenceNote)"),
            ("referenceNoteName", CSVParserHelpers.formatNoteName(payload.referenceNote)),
            ("targetNote", "\(payload.targetNote)"),
            ("targetNoteName", CSVParserHelpers.formatNoteName(payload.targetNote)),
            ("interval", CSVParserHelpers.formatInterval(payload.interval)),
            ("tuningSystem", payload.tuningSystem),
            ("centOffset", CSVParserHelpers.formatDouble(payload.centOffset)),
            ("isCorrect", payload.isCorrect ? "true" : "false"),
        ]
    }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: PitchDiscriminationPayload), CSVImportError> {
        PitchDiscriminationCSVParser.parse(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: PitchDiscriminationPayload)] {
        try store.fetchPayloads(PitchDiscriminationPayload.self)
            .filter { $0.payload.interval != 0 }
            .map { ($0.timestamp, $0.payload) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: PitchDiscriminationPayload)] {
        TrainingDisciplinePayloads.typedEntries(
            from: parseResult,
            forTrainingType: csvTrainingType,
            ofType: PitchDiscriminationPayload.self
        )
        .filter { $0.payload.interval != 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        var existing = try buildPitchDuplicateKeys(discriminationsIn: store, trainingType: csvTrainingType)
        return try scope.mergeImportPayloads(parsedRecords(from: parseResult), existing: &existing) {
            PitchDuplicateKey(timestamp: $0, payload: $1, trainingType: csvTrainingType)
        }
    }
}

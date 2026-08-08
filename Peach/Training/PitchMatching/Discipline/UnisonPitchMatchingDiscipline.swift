import Foundation

struct UnisonPitchMatchingDiscipline: TrainingDisciplineUI, Sendable {
    let id = TrainingDisciplineID.unisonPitchMatching

    let category: TrainingCategory = .pitch

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Match Pitch"),
        shortLabel: String(localized: "Match"),
        systemImageName: "target",
        isHero: false,
        helpDescription: String(localized: "Hear a note and slide to match its pitch."),
        unitLabel: String(localized: "cents"),
        unitSymbol: String(localized: "¢"),
        optimalBaseline: 5.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    var helpSections: [HelpSection] { PitchMatchingHelp.trainingScreen }

    let navigationDestination: NavigationDestination = .pitchMatching(isIntervalMode: false)

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for entry in try store.fetchPayloads(PitchMatchingPayload.self) where entry.payload.interval == 0 {
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

    var csvHistory: CSVHistory { PitchMatchingCSVHistory.history }

    func csvKeyValuePairs(for payload: PitchMatchingPayload) -> [(String, String)] {
        [
            ("referenceNote", "\(payload.referenceNote)"),
            ("referenceNoteName", CSVParserHelpers.formatNoteName(payload.referenceNote)),
            ("targetNote", "\(payload.targetNote)"),
            ("targetNoteName", CSVParserHelpers.formatNoteName(payload.targetNote)),
            ("interval", CSVParserHelpers.formatInterval(payload.interval)),
            ("tuningSystem", payload.tuningSystem),
            ("initialCentOffset", CSVParserHelpers.formatDouble(payload.initialCentOffset)),
            ("userCentError", CSVParserHelpers.formatDouble(payload.userCentError)),
        ]
    }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: PitchMatchingPayload), CSVImportError> {
        PitchMatchingCSVParser.parse(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: PitchMatchingPayload)] {
        try store.fetchPayloads(PitchMatchingPayload.self)
            .filter { $0.payload.interval == 0 }
            .map { ($0.timestamp, $0.payload) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: PitchMatchingPayload)] {
        TrainingDisciplinePayloads.typedEntries(
            from: parseResult,
            forTrainingType: csvTrainingType,
            ofType: PitchMatchingPayload.self
        )
        .filter { $0.payload.interval == 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        var existing = try buildPitchDuplicateKeys(matchingsIn: store, trainingType: csvTrainingType)
        return try scope.mergeImportPayloads(parsedRecords(from: parseResult), existing: &existing) {
            PitchDuplicateKey(timestamp: $0, payload: $1, trainingType: csvTrainingType)
        }
    }
}

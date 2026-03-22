import Foundation

nonisolated enum CSVImportParser {

    struct ImportResult {
        var pitchDiscriminations: [PitchDiscriminationRecord]
        var pitchMatchings: [PitchMatchingRecord]
        var rhythmOffsetDetections: [RhythmOffsetDetectionRecord]
        var continuousRhythmMatchings: [ContinuousRhythmMatchingRecord]
        var errors: [CSVImportError]
    }

    private static let parsers: [any CSVVersionedParser] = [CSVImportParserV1(), CSVImportParserV2()]

    static func parse(_ csvContent: String) -> ImportResult {
        let versionResult = CSVFormatVersionReader.readVersion(from: csvContent)

        switch versionResult {
        case .failure(let error):
            return ImportResult(pitchDiscriminations: [], pitchMatchings: [], rhythmOffsetDetections: [], continuousRhythmMatchings: [], errors: [error])

        case .success(let version, let remainingLines):
            guard let parser = parsers.first(where: { $0.supportedVersion == version }) else {
                return ImportResult(pitchDiscriminations: [], pitchMatchings: [], rhythmOffsetDetections: [], continuousRhythmMatchings: [], errors: [.unsupportedVersion(version: version)])
            }
            return parser.parse(lines: remainingLines)
        }
    }
}

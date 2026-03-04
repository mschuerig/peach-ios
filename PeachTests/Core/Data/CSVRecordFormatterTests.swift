import Testing
import Foundation
@testable import Peach

@Suite("CSVRecordFormatter Tests")
struct CSVRecordFormatterTests {

    // MARK: - Test Helpers

    private func fixedDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 3, hour: 14, minute: 30, second: 0)
        return calendar.date(from: components)!
    }

    // MARK: - ComparisonRecord Formatting

    @Test("ComparisonRecord formatting produces correct CSV row with empty pitch-matching fields")
    func formatComparisonRecord() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 64,
            centOffset: 15.5,
            isCorrect: true,
            interval: 4,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[0] == "comparison")
        #expect(fields[1] == "2026-03-03T14:30:00Z")
        #expect(fields[2] == "60")
        #expect(fields[3] == "C4")
        #expect(fields[4] == "64")
        #expect(fields[5] == "E4")
        #expect(fields[6] == "M3")
        #expect(fields[7] == "equalTemperament")
        #expect(fields[8] == "15.5")
        #expect(fields[9] == "true")
        #expect(fields[10] == "")
        #expect(fields[11] == "")
    }

    // MARK: - PitchMatchingRecord Formatting

    @Test("PitchMatchingRecord formatting produces correct CSV row with empty comparison fields")
    func formatPitchMatchingRecord() async {
        let record = PitchMatchingRecord(
            referenceNote: 60,
            targetNote: 67,
            initialCentOffset: 25.0,
            userCentError: 3.2,
            interval: 7,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[0] == "pitchMatching")
        #expect(fields[1] == "2026-03-03T14:30:00Z")
        #expect(fields[2] == "60")
        #expect(fields[3] == "C4")
        #expect(fields[4] == "67")
        #expect(fields[5] == "G4")
        #expect(fields[6] == "P5")
        #expect(fields[7] == "equalTemperament")
        #expect(fields[8] == "")
        #expect(fields[9] == "")
        #expect(fields[10] == "25.0")
        #expect(fields[11] == "3.2")
    }

    // MARK: - Timestamp Formatting

    @Test("timestamp truncates sub-second precision for round-trip fidelity")
    func timestampTruncatesSubSeconds() async {
        let date = Date(timeIntervalSinceReferenceDate: 794_394_000.999)
        let record = ComparisonRecord(
            referenceNote: 60, targetNote: 60, centOffset: 0.0, isCorrect: true,
            interval: 0, tuningSystem: "equalTemperament", timestamp: date
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(!fields[1].contains("."))

        let parsed = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(fields[1])
        #expect(parsed != nil)
        #expect(abs(parsed!.timeIntervalSince(date)) < 1.0)
    }

    @Test("timestamp formatting is ISO 8601 UTC")
    func timestampFormatIsISO8601() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 0.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[1] == "2026-03-03T14:30:00Z")
    }

    // MARK: - Note Name Formatting

    @Test("note name formatting for MIDI 0 produces C-1")
    func noteNameMIDI0() async {
        let record = ComparisonRecord(
            referenceNote: 0,
            targetNote: 0,
            centOffset: 5.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[3] == "C-1")
        #expect(fields[5] == "C-1")
    }

    @Test("note name formatting for MIDI 127 produces G9")
    func noteNameMIDI127() async {
        let record = ComparisonRecord(
            referenceNote: 127,
            targetNote: 127,
            centOffset: 5.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[3] == "G9")
        #expect(fields[5] == "G9")
    }

    // MARK: - Interval Abbreviation Formatting

    @Test("interval abbreviation formatting for all intervals")
    func intervalAbbreviations() async {
        let expectedAbbreviations: [(Int, String)] = [
            (0, "P1"), (1, "m2"), (2, "M2"), (3, "m3"), (4, "M3"),
            (5, "P4"), (6, "d5"), (7, "P5"), (8, "m6"), (9, "M6"),
            (10, "m7"), (11, "M7"), (12, "P8"),
        ]

        for (semitones, expectedAbbrev) in expectedAbbreviations {
            let record = ComparisonRecord(
                referenceNote: 60,
                targetNote: 60 + semitones,
                centOffset: 0.0,
                isCorrect: true,
                interval: semitones,
                tuningSystem: "equalTemperament",
                timestamp: fixedDate()
            )

            let row = CSVRecordFormatter.format(record)
            let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

            #expect(fields[6] == expectedAbbrev, "Expected \(expectedAbbrev) for semitones \(semitones), got \(fields[6])")
        }
    }

    @Test("invalid interval rawValue produces empty string")
    func invalidIntervalProducesEmpty() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 84,
            centOffset: 0.0,
            isCorrect: true,
            interval: 99,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[6] == "")
    }

    // MARK: - RFC 4180 Escaping

    @Test("field containing comma is wrapped in quotes")
    func commaFieldIsEscaped() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 0.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equal,Temperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        #expect(row.contains("\"equal,Temperament\""))
    }

    @Test("field containing quotes is properly escaped")
    func quotedFieldIsEscaped() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 0.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "say \"hi\"",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        #expect(row.contains("\"say \"\"hi\"\"\""))
    }

    @Test("field containing newline is wrapped in quotes")
    func newlineFieldIsEscaped() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 0.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "line1\nline2",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        #expect(row.contains("\"line1\nline2\""))
    }

    @Test("field without special characters is not quoted")
    func normalFieldNotEscaped() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 0.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(fields[7] == "equalTemperament")
    }

    // MARK: - Edge Case Values

    @Test("negative cent offset formats correctly")
    func negativeCentOffset() async {
        let record = ComparisonRecord(
            referenceNote: 69,
            targetNote: 62,
            centOffset: -8.3,
            isCorrect: false,
            interval: 7,
            tuningSystem: "justIntonation",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[0] == "comparison")
        #expect(fields[7] == "justIntonation")
        #expect(fields[8] == "-8.3")
        #expect(fields[9] == "false")
    }

    @Test("zero cent offset formats as 0.0")
    func zeroCentOffset() async {
        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 0.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate()
        )

        let row = CSVRecordFormatter.format(record)
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields[8] == "0.0")
    }

    @Test("both tuning system identifiers format correctly")
    func tuningSystemIdentifiers() async {
        let record1 = ComparisonRecord(
            referenceNote: 60, targetNote: 60, centOffset: 0.0, isCorrect: true,
            interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let record2 = ComparisonRecord(
            referenceNote: 60, targetNote: 60, centOffset: 0.0, isCorrect: true,
            interval: 0, tuningSystem: "justIntonation", timestamp: fixedDate()
        )

        let row1 = CSVRecordFormatter.format(record1)
        let row2 = CSVRecordFormatter.format(record2)

        #expect(row1.contains("equalTemperament"))
        #expect(row2.contains("justIntonation"))
    }
}

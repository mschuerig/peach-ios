import Foundation
import SwiftData

/// Shared CSV row parsing for PitchDiscriminationRecord.
/// Used by both UnisonPitchDiscriminationDiscipline and IntervalPitchDiscriminationDiscipline.
enum PitchDiscriminationCSVParser {

    static func parse(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<any PersistentModel, CSVImportError> {
        guard let timestampIdx = columnIndex["timestamp"],
              let refNoteIdx = columnIndex["referenceNote"],
              let targetNoteIdx = columnIndex["targetNote"],
              let intervalIdx = columnIndex["interval"],
              let tuningSystemIdx = columnIndex["tuningSystem"],
              let centOffsetIdx = columnIndex["centOffset"],
              let isCorrectIdx = columnIndex["isCorrect"] else {
            return .failure(.invalidRowData(row: rowNumber, column: "row", value: "", reason: "missing required columns"))
        }

        let timestampStr = fields[timestampIdx]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .failure(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let refNoteStr = fields[refNoteIdx]
        guard let referenceNote = Int(refNoteStr), MIDINote.validRange.contains(referenceNote) else {
            return .failure(.invalidRowData(row: rowNumber, column: "referenceNote", value: refNoteStr, reason: "must be an integer 0-127"))
        }

        let targetNoteStr = fields[targetNoteIdx]
        guard let targetNote = Int(targetNoteStr), MIDINote.validRange.contains(targetNote) else {
            return .failure(.invalidRowData(row: rowNumber, column: "targetNote", value: targetNoteStr, reason: "must be an integer 0-127"))
        }

        let intervalStr = fields[intervalIdx]
        guard let intervalRaw = CSVParserHelpers.abbreviationToRawValue[intervalStr] else {
            return .failure(.invalidRowData(row: rowNumber, column: "interval", value: intervalStr, reason: "not a valid interval abbreviation"))
        }

        let tuningSystemStr = fields[tuningSystemIdx]
        guard TuningSystem(identifier: tuningSystemStr) != nil else {
            return .failure(.invalidRowData(row: rowNumber, column: "tuningSystem", value: tuningSystemStr, reason: "not a valid tuning system"))
        }

        let centOffsetStr = fields[centOffsetIdx]
        guard let centOffset = Double(centOffsetStr), centOffset.isFinite else {
            return .failure(.invalidRowData(row: rowNumber, column: "centOffset", value: centOffsetStr, reason: "not a valid number"))
        }

        let isCorrectStr = fields[isCorrectIdx]
        guard isCorrectStr == "true" || isCorrectStr == "false" else {
            return .failure(.invalidRowData(row: rowNumber, column: "isCorrect", value: isCorrectStr, reason: "must be 'true' or 'false'"))
        }

        let record = PitchDiscriminationRecord(
            referenceNote: referenceNote,
            targetNote: targetNote,
            centOffset: centOffset,
            isCorrect: isCorrectStr == "true",
            interval: intervalRaw,
            tuningSystem: tuningSystemStr,
            timestamp: timestamp
        )
        return .success(record)
    }
}

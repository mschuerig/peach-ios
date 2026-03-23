import Foundation
import SwiftData

/// Shared CSV row parsing for PitchMatchingRecord.
/// Used by both UnisonPitchMatchingDiscipline and IntervalPitchMatchingDiscipline.
enum PitchMatchingCSVParser {

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
              let initialCentOffsetIdx = columnIndex["initialCentOffset"],
              let userCentErrorIdx = columnIndex["userCentError"] else {
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

        let initialCentOffsetStr = fields[initialCentOffsetIdx]
        guard let initialCentOffset = Double(initialCentOffsetStr), initialCentOffset.isFinite else {
            return .failure(.invalidRowData(row: rowNumber, column: "initialCentOffset", value: initialCentOffsetStr, reason: "not a valid number"))
        }

        let userCentErrorStr = fields[userCentErrorIdx]
        guard let userCentError = Double(userCentErrorStr), userCentError.isFinite else {
            return .failure(.invalidRowData(row: rowNumber, column: "userCentError", value: userCentErrorStr, reason: "not a valid number"))
        }

        let record = PitchMatchingRecord(
            referenceNote: referenceNote,
            targetNote: targetNote,
            initialCentOffset: initialCentOffset,
            userCentError: userCentError,
            interval: intervalRaw,
            tuningSystem: tuningSystemStr,
            timestamp: timestamp
        )
        return .success(record)
    }
}

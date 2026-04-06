import Foundation
import SwiftData
import Testing
@testable import Peach

@Suite("DuplicateKey")
struct DuplicateKeyTests {

    // MARK: - PitchDuplicateKey

    @Test("pitch duplicate keys with same fields are equal")
    func pitchDuplicateKeysEquality() async {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let key1 = PitchDuplicateKey(timestamp: date, referenceNote: 60, targetNote: 62, trainingType: "pitchDiscrimination")
        let key2 = PitchDuplicateKey(timestamp: date, referenceNote: 60, targetNote: 62, trainingType: "pitchDiscrimination")

        #expect(key1 == key2)
    }

    @Test("pitch duplicate keys with different timestamps are not equal")
    func pitchDuplicateKeysDifferentTimestamp() async {
        let key1 = PitchDuplicateKey(timestamp: Date(timeIntervalSinceReferenceDate: 1000), referenceNote: 60, targetNote: 62, trainingType: "pitchDiscrimination")
        let key2 = PitchDuplicateKey(timestamp: Date(timeIntervalSinceReferenceDate: 2000), referenceNote: 60, targetNote: 62, trainingType: "pitchDiscrimination")

        #expect(key1 != key2)
    }

    @Test("pitch duplicate key from PitchDiscriminationRecord")
    func pitchDuplicateKeyFromDiscriminationRecord() async {
        let date = Date(timeIntervalSinceReferenceDate: 5000)
        let record = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 62, centOffset: 15.0,
            isCorrect: true, interval: 0, tuningSystem: "equalTemperament",
            timestamp: date
        )
        let key = PitchDuplicateKey(record: record)

        #expect(key.referenceNote == 60)
        #expect(key.targetNote == 62)
        #expect(key.trainingType == "pitchDiscrimination")
    }

    @Test("pitch duplicate key from PitchMatchingRecord")
    func pitchDuplicateKeyFromMatchingRecord() async {
        let date = Date(timeIntervalSinceReferenceDate: 5000)
        let record = PitchMatchingRecord(
            referenceNote: 60, targetNote: 67, initialCentOffset: 30.0,
            userCentError: 5.0, interval: 7, tuningSystem: "equalTemperament",
            timestamp: date
        )
        let key = PitchDuplicateKey(record: record)

        #expect(key.referenceNote == 60)
        #expect(key.targetNote == 67)
        #expect(key.trainingType == "pitchMatching")
    }

    // MARK: - RhythmDuplicateKey

    @Test("rhythm duplicate keys with same fields are equal")
    func rhythmDuplicateKeysEquality() async {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let key1 = RhythmDuplicateKey(timestamp: date, tempoBPM: 120, trainingType: "rhythmOffsetDetection")
        let key2 = RhythmDuplicateKey(timestamp: date, tempoBPM: 120, trainingType: "rhythmOffsetDetection")

        #expect(key1 == key2)
    }

    @Test("rhythm duplicate keys with different training types are not equal")
    func rhythmDuplicateKeysDifferentType() async {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let key1 = RhythmDuplicateKey(timestamp: date, tempoBPM: 120, trainingType: "rhythmOffsetDetection")
        let key2 = RhythmDuplicateKey(timestamp: date, tempoBPM: 120, trainingType: "continuousRhythmMatching")

        #expect(key1 != key2)
    }
}

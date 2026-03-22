import Foundation

/// Maps storage records to domain-level metric points via a profile builder.
///
/// This lives in the app layer so that neither `PerceptualProfile` nor `ProgressTimeline`
/// needs to import or reference storage record types.
enum MetricPointMapper {

    /// Feeds all training records from the data store into a profile builder.
    static func feedAllRecords(from dataStore: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        feedPitchDiscriminations(try dataStore.fetchAllPitchDiscriminations(), into: builder)
        feedPitchMatchings(try dataStore.fetchAllPitchMatchings(), into: builder)
        feedRhythmOffsetDetections(try dataStore.fetchAllRhythmOffsetDetections(), into: builder)
        feedRhythmMatchings(try dataStore.fetchAllRhythmMatchings(), into: builder)
        feedContinuousRhythmMatchings(try dataStore.fetchAllContinuousRhythmMatchings(), into: builder)
    }

    static func feedPitchDiscriminations(_ records: [PitchDiscriminationRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let mode: TrainingDiscipline = record.interval == 0 ? .unisonPitchDiscrimination : .intervalPitchDiscrimination
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.centOffset)),
                for: .pitch(mode),
                isCorrect: record.isCorrect
            )
        }
    }

    static func feedPitchMatchings(_ records: [PitchMatchingRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let mode: TrainingDiscipline = record.interval == 0 ? .unisonPitchMatching : .intervalPitchMatching
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.userCentError)),
                for: .pitch(mode)
            )
        }
    }

    static func feedRhythmOffsetDetections(_ records: [RhythmOffsetDetectionRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let offset = RhythmOffset(.milliseconds(record.offsetMs))
            guard let range = TempoRange.range(for: TempoBPM(record.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.offsetMs)),
                for: .rhythm(.rhythmOffsetDetection, range, offset.direction),
                isCorrect: record.isCorrect
            )
        }
    }

    static func feedRhythmMatchings(_ records: [RhythmMatchingRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let offset = RhythmOffset(.milliseconds(record.userOffsetMs))
            guard let range = TempoRange.range(for: TempoBPM(record.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.userOffsetMs)),
                for: .rhythm(.rhythmMatching, range, offset.direction)
            )
        }
    }

    static func feedContinuousRhythmMatchings(_ records: [ContinuousRhythmMatchingRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let offset = RhythmOffset(.milliseconds(record.meanOffsetMs))
            guard let range = TempoRange.range(for: TempoBPM(record.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.meanOffsetMs)),
                for: .rhythm(.continuousRhythmMatching, range, offset.direction)
            )
        }
    }
}

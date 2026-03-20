import Foundation

/// Maps storage records to domain-level metric points via a profile builder.
///
/// This lives in the app layer so that neither `PerceptualProfile` nor `ProgressTimeline`
/// needs to import or reference storage record types.
enum MetricPointMapper {

    /// Feeds all training records from the data store into a profile builder.
    static func feedAllRecords(from dataStore: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        feedPitchComparisons(try dataStore.fetchAllPitchComparisons(), into: builder)
        feedPitchMatchings(try dataStore.fetchAllPitchMatchings(), into: builder)
        feedRhythmComparisons(try dataStore.fetchAllRhythmComparisons(), into: builder)
        feedRhythmMatchings(try dataStore.fetchAllRhythmMatchings(), into: builder)
    }

    static func feedPitchComparisons(_ records: [PitchComparisonRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let mode: TrainingMode = record.interval == 0 ? .unisonPitchComparison : .intervalPitchComparison
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.centOffset)),
                for: .pitch(mode),
                isCorrect: record.isCorrect
            )
        }
    }

    static func feedPitchMatchings(_ records: [PitchMatchingRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let mode: TrainingMode = record.interval == 0 ? .unisonMatching : .intervalMatching
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.userCentError)),
                for: .pitch(mode)
            )
        }
    }

    static func feedRhythmComparisons(_ records: [RhythmComparisonRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let offset = RhythmOffset(.milliseconds(record.offsetMs))
            guard let range = TempoRange.range(for: TempoBPM(record.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.offsetMs)),
                for: .rhythm(.rhythmComparison, range, offset.direction),
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
}

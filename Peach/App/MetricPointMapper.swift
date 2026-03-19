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
    }

    static func feedPitchComparisons(_ records: [PitchComparisonRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let mode: TrainingMode = record.interval == 0 ? .unisonPitchComparison : .intervalPitchComparison
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: Cents(abs(record.centOffset))),
                for: mode,
                isCorrect: record.isCorrect
            )
        }
    }

    static func feedPitchMatchings(_ records: [PitchMatchingRecord], into builder: PerceptualProfile.Builder) {
        for record in records {
            let mode: TrainingMode = record.interval == 0 ? .unisonMatching : .intervalMatching
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: Cents(abs(record.userCentError))),
                for: mode
            )
        }
    }
}

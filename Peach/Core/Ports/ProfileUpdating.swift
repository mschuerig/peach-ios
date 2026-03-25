import Foundation

/// Port protocol for updating the perceptual profile with training results.
///
/// Discipline-specific adapters map their trial results to calls on this protocol,
/// keeping the profile implementation free of discipline knowledge.
protocol ProfileUpdating {
    func update(_ key: StatisticsKey, timestamp: Date, value: Double)
}

import Foundation

struct TrainingModeConfig {
    let displayName: String
    let unitLabel: String
    let optimalBaseline: Double
    let ewmaHalflifeDays: Double
    let coldStartThreshold: Int
    let trendThreshold: Int
}

extension TrainingModeConfig {
    static let unisonComparison = TrainingModeConfig(
        displayName: "Unison Comparison",
        unitLabel: "cents",
        optimalBaseline: 8.0,
        ewmaHalflifeDays: 7.0,
        coldStartThreshold: 20,
        trendThreshold: 100
    )

    static let intervalComparison = TrainingModeConfig(
        displayName: "Interval Comparison",
        unitLabel: "cents",
        optimalBaseline: 12.0,
        ewmaHalflifeDays: 7.0,
        coldStartThreshold: 20,
        trendThreshold: 100
    )

    static let unisonMatching = TrainingModeConfig(
        displayName: "Unison Matching",
        unitLabel: "cents",
        optimalBaseline: 5.0,
        ewmaHalflifeDays: 7.0,
        coldStartThreshold: 20,
        trendThreshold: 100
    )

    static let intervalMatching = TrainingModeConfig(
        displayName: "Interval Matching",
        unitLabel: "cents",
        optimalBaseline: 8.0,
        ewmaHalflifeDays: 7.0,
        coldStartThreshold: 20,
        trendThreshold: 100
    )
}

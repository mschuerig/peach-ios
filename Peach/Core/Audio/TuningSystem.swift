import Foundation

enum TuningSystem: Hashable, Sendable, CaseIterable, Codable {
    case equalTemperament

    func centOffset(for interval: Interval) -> Double {
        switch self {
        case .equalTemperament:
            return Double(interval.semitones) * 100.0
        }
    }
}

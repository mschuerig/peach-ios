import Foundation

struct IntervalSelection: RawRepresentable, Equatable, Sendable {
    var intervals: Set<DirectedInterval>

    init(_ intervals: Set<DirectedInterval>) {
        self.intervals = intervals
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Set<DirectedInterval>.self, from: data),
              !decoded.isEmpty else {
            return nil
        }
        intervals = decoded
    }

    // Explicit Equatable — the RawRepresentable default compares rawValue
    // (JSON strings) whose key ordering is non-deterministic, causing
    // intermittent equality failures for identical interval sets.
    static func == (lhs: IntervalSelection, rhs: IntervalSelection) -> Bool {
        lhs.intervals == rhs.intervals
    }

    func isLastRemaining(_ interval: DirectedInterval) -> Bool {
        intervals.count == 1 && intervals.contains(interval)
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(intervals),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static let `default` = SettingsKeys.defaultIntervalSelection
}

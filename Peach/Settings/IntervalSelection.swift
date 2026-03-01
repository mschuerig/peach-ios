import Foundation

struct IntervalSelection: RawRepresentable, Equatable, Sendable {
    var intervals: Set<DirectedInterval>

    init(_ intervals: Set<DirectedInterval>) {
        self.intervals = intervals
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Set<DirectedInterval>.self, from: data) else {
            return nil
        }
        intervals = decoded
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(intervals),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static let `default` = IntervalSelection([.up(.perfectFifth)])
}

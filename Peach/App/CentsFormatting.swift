import Foundation

extension Cents {
    func formatted() -> String {
        MetricValueFormatter.format(rawValue)
    }
}

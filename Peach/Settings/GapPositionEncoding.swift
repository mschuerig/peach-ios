import Foundation

enum GapPositionEncoding {
    static func encode(_ positions: Set<StepPosition>) -> String {
        positions
            .map(\.rawValue)
            .sorted()
            .map(String.init)
            .joined(separator: ",")
    }

    static func decode(_ string: String) -> Set<StepPosition> {
        let positions = string
            .split(separator: ",")
            .compactMap { Int($0) }
            .compactMap(StepPosition.init(rawValue:))
        return Set(positions)
    }

    static func decodeWithDefault(_ string: String) -> Set<StepPosition> {
        let decoded = decode(string)
        return decoded.isEmpty ? SettingsKeys.defaultEnabledGapPositions : decoded
    }
}

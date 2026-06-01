import Foundation

enum GapPositionEncoding {
    static func encode(_ positions: Set<BeatPosition>) -> String {
        positions
            .map(\.rawValue)
            .sorted()
            .map(String.init)
            .joined(separator: ",")
    }

    static func decode(_ string: String) -> Set<BeatPosition> {
        let positions = string
            .split(separator: ",")
            .compactMap { Int($0) }
            .compactMap(BeatPosition.init(rawValue:))
        return Set(positions)
    }

    static func decodeWithDefault(_ string: String) -> Set<BeatPosition> {
        let decoded = decode(string)
        return decoded.isEmpty ? ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions : decoded
    }
}

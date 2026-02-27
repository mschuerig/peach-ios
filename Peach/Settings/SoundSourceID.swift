import Foundation

struct SoundSourceID: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue.isEmpty ? "sf2:8:80" : rawValue
    }
}

// MARK: - ExpressibleByStringLiteral

extension SoundSourceID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(value)
    }
}

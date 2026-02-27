import Foundation

struct SoundSourceID: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "SoundSourceID must not be empty")
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByStringLiteral

extension SoundSourceID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(value)
    }
}

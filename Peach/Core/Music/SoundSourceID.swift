protocol SoundSourceID: Sendable {
    var rawValue: String { get }
    var displayName: String { get }
}

/// Lightweight identifier used by settings to store a sound source selection
/// without needing the full preset catalog. Display name is intentionally empty —
/// UI display names come from `SoundSourceProvider`.
struct SoundSourceTag: SoundSourceID, Hashable {
    let rawValue: String
    var displayName: String { "" }
}

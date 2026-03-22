import Foundation

/// Defines the possible navigation destinations in the app's hub-and-spoke navigation pattern.
/// Used by NavigationStack with value-based navigation for type-safe routing.
enum NavigationDestination: Hashable {
    case pitchDiscrimination(isIntervalMode: Bool)
    case pitchMatching(isIntervalMode: Bool)
    case settings
    case profile
    case rhythmOffsetDetection
    case rhythmMatching
    case continuousRhythmMatching
}

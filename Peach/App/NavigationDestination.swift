import Foundation

/// Defines the possible navigation destinations in the app's hub-and-spoke navigation pattern.
/// Used by NavigationStack with value-based navigation for type-safe routing.
enum NavigationDestination: Hashable {
    case training
    case pitchMatching
    case settings
    case profile
}

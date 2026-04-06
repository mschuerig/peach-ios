import Testing
import SwiftUI
@testable import Peach

/// Navigation and UI tests for Start Screen and related views.
///
/// **Test Limitations:** These tests verify structural validity (views can be instantiated,
/// enums have expected cases) using reflection. Full behavioral testing (user interactions,
/// navigation state changes, accessibility verification) would require UI testing frameworks
/// beyond Swift Testing's current capabilities for SwiftUI views.
///
/// **Future Improvement:** Consider adding XCTest UI tests for complete interaction coverage
/// when more complex navigation scenarios are implemented in Epic 3 Story 2+.
@Suite("Start Screen Tests")
struct StartScreenTests {

    // MARK: - View Instantiation Tests

    @Test("Start Screen can be instantiated")
    func startScreenCanBeInstantiated() async {
        let view = StartScreen()
        let mirror = Mirror(reflecting: view)

        // Verify view has expected structure
        #expect(mirror.children.count > 0)
    }

    @Test("Comparison Screen can be instantiated for unison mode")
    func comparisonScreenCanBeInstantiatedUnison() async {
        _ = PitchDiscriminationScreen(isIntervalMode: false)
    }

    @Test("Comparison Screen can be instantiated for interval mode")
    func comparisonScreenCanBeInstantiatedInterval() async {
        _ = PitchDiscriminationScreen(isIntervalMode: true)
    }

    @Test("Pitch Matching Screen can be instantiated for interval mode")
    func pitchMatchingScreenCanBeInstantiatedInterval() async {
        _ = PitchMatchingScreen(isIntervalMode: true)
    }

    @Test("Settings Screen can be instantiated")
    func settingsScreenCanBeInstantiated() async {
        _ = SettingsScreen()
    }

    @Test("Profile Screen can be instantiated")
    func profileScreenCanBeInstantiated() async {
        _ = ProfileScreen()
    }

    @Test("Info Screen can be instantiated")
    func infoScreenCanBeInstantiated() async {
        let view = InfoScreen()
        let mirror = Mirror(reflecting: view)

        // Verify view exists
        #expect(mirror.children.count > 0)
    }

    @Test("ContentView can be instantiated")
    func contentViewCanBeInstantiated() async {
        _ = ContentView()
    }

    // MARK: - Navigation Destination Tests

    @Test("NavigationDestination enum has comparison case with interval mode flag")
    func navigationDestinationHasComparison() async {
        let destination = NavigationDestination.pitchDiscrimination(isIntervalMode: false)
        #expect(destination == NavigationDestination.pitchDiscrimination(isIntervalMode: false))
    }

    @Test("NavigationDestination enum has pitchMatching case with interval mode flag")
    func navigationDestinationHasPitchMatching() async {
        let destination = NavigationDestination.pitchMatching(isIntervalMode: false)
        #expect(destination == NavigationDestination.pitchMatching(isIntervalMode: false))
    }

    @Test("NavigationDestination enum has settings case")
    func navigationDestinationHasSettings() async {
        let destination = NavigationDestination.settings
        #expect(destination == NavigationDestination.settings)
    }

    @Test("NavigationDestination enum has profile case")
    func navigationDestinationHasProfile() async {
        let destination = NavigationDestination.profile
        #expect(destination == NavigationDestination.profile)
    }

    @Test("NavigationDestination enum has timingOffsetDetection case")
    func navigationDestinationHasTimingOffsetDetection() async {
        let destination = NavigationDestination.timingOffsetDetection
        #expect(destination == NavigationDestination.timingOffsetDetection)
    }

    @Test("NavigationDestination enum has continuousRhythmMatching case")
    func navigationDestinationHasContinuousRhythmMatching() async {
        let destination = NavigationDestination.continuousRhythmMatching
        #expect(destination == NavigationDestination.continuousRhythmMatching)
    }

    @Test("NavigationDestination enum is Hashable")
    func navigationDestinationIsHashable() async {
        let destination1 = NavigationDestination.pitchDiscrimination(isIntervalMode: false)
        let destination2 = NavigationDestination.pitchDiscrimination(isIntervalMode: false)
        let destination3 = NavigationDestination.settings

        #expect(destination1.hashValue == destination2.hashValue)
        #expect(destination1.hashValue != destination3.hashValue)
    }

    @Test("NavigationDestination comparison cases with different modes are not equal")
    func navigationDestinationComparisonDifferentModes() async {
        let unison = NavigationDestination.pitchDiscrimination(isIntervalMode: false)
        let interval = NavigationDestination.pitchDiscrimination(isIntervalMode: true)
        #expect(unison != interval)
    }

    @Test("NavigationDestination pitchMatching cases with different modes are not equal")
    func navigationDestinationPitchMatchingDifferentModes() async {
        let unison = NavigationDestination.pitchMatching(isIntervalMode: false)
        let interval = NavigationDestination.pitchMatching(isIntervalMode: true)
        #expect(unison != interval)
    }

    @Test("NavigationDestination cases are not equal when different")
    func navigationDestinationCasesAreDistinct() async {
        #expect(NavigationDestination.pitchDiscrimination(isIntervalMode: false) != NavigationDestination.settings)
        #expect(NavigationDestination.settings != NavigationDestination.profile)
        #expect(NavigationDestination.pitchDiscrimination(isIntervalMode: false) != NavigationDestination.profile)
        #expect(NavigationDestination.pitchDiscrimination(isIntervalMode: false) != NavigationDestination.pitchMatching(isIntervalMode: false))
    }

    // MARK: - Info Screen Content Tests

    @Test("Info Screen has correct GitHub URL")
    func infoScreenHasCorrectGitHubURL() async {
        #expect(InfoScreen.gitHubURL == URL(string: "https://github.com/mschuerig/peach")!)
    }

    @Test("Info Screen has correct developer name")
    func infoScreenHasCorrectDeveloperName() async {
        #expect(InfoScreen.developerName == "Michael Schürig")
    }

    @Test("Info Screen copyright notice contains current year and developer name")
    func infoScreenHasCopyrightNotice() async {
        let currentYear = Calendar.current.component(.year, from: Date())
        #expect(InfoScreen.copyrightNotice.contains("\(currentYear)"))
        #expect(InfoScreen.copyrightNotice.contains(InfoScreen.developerName))
        #expect(InfoScreen.copyrightNotice.contains("©"))
    }

    @Test("Info Screen has correct license name")
    func infoScreenHasCorrectLicenseName() async {
        #expect(InfoScreen.licenseName == "MIT")
    }

    @Test("Info Screen has non-empty version string")
    func infoScreenHasNonEmptyVersion() async {
        let view = InfoScreen()

        let mirror = Mirror(reflecting: view)
        let appVersionProperty = mirror.children.first(where: { $0.label == "appVersion" })

        #expect(appVersionProperty != nil)

        if let version = appVersionProperty?.value as? String {
            // In the test target, Bundle.main is the test runner bundle so
            // CFBundleShortVersionString is absent and appVersion falls back
            // to "Unknown". This verifies the fallback produces a non-empty string.
            #expect(!version.isEmpty)
        }
    }

    // MARK: - Info Screen Help Content Tests

    @Test("Info Screen app description mentions Peach")
    func infoScreenHasAppDescription() async {
        #expect(InfoScreen.appDescription.contains("Peach"))
        #expect(InfoScreen.appDescription.count > 50)
    }

    @Test("Info Screen training modes description contains dash-separated mode names")
    func infoScreenHasTrainingModesDescription() async {
        let description = InfoScreen.trainingModesDescription
        #expect(description.contains("–"))
        #expect(description.count > 100)
    }

    @Test("Info Screen has three help sections")
    func infoScreenHasThreeHelpSections() async {
        #expect(InfoScreen.helpSections.count == 3)
    }

    @Test("Info Screen getting started text mentions Peach")
    func infoScreenHasGettingStarted() async {
        #expect(InfoScreen.gettingStartedText.contains("Peach"))
        #expect(InfoScreen.gettingStartedText.count > 30)
    }

    // MARK: - Hub and Spoke Pattern Verification

    @Test("All navigation destinations can be created")
    func allNavigationDestinationsCanBeCreated() async {
        let comparison = PitchDiscriminationScreen(isIntervalMode: false)
        let intervalComparison = PitchDiscriminationScreen(isIntervalMode: true)
        let pitchMatching = PitchMatchingScreen(isIntervalMode: false)
        let intervalPitchMatching = PitchMatchingScreen(isIntervalMode: true)
        let settings = SettingsScreen()
        let profile = ProfileScreen()
        let info = InfoScreen()
        let timingOffsetDetection = TimingOffsetDetectionScreen()
        let continuousRhythmMatching = ContinuousRhythmMatchingScreen()

        // If we can create all screens without crashing, navigation paths are valid
        _ = (comparison, intervalComparison, pitchMatching, intervalPitchMatching, settings, profile, info, timingOffsetDetection, continuousRhythmMatching)
    }
}

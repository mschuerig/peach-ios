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
    func startScreenCanBeInstantiated() {
        let view = StartScreen()
        let mirror = Mirror(reflecting: view)

        // Verify view has expected structure
        #expect(mirror.children.count > 0)
    }

    @Test("Comparison Screen can be instantiated with prime intervals")
    func comparisonScreenCanBeInstantiated() {
        _ = ComparisonScreen(intervals: [.prime])
    }

    @Test("Comparison Screen can be instantiated with perfectFifth intervals")
    func comparisonScreenCanBeInstantiatedWithPerfectFifth() async {
        _ = ComparisonScreen(intervals: [.up(.perfectFifth)])
    }

    @Test("Pitch Matching Screen can be instantiated with perfectFifth intervals")
    func pitchMatchingScreenCanBeInstantiatedWithPerfectFifth() async {
        _ = PitchMatchingScreen(intervals: [.up(.perfectFifth)])
    }

    @Test("Settings Screen can be instantiated")
    func settingsScreenCanBeInstantiated() {
        _ = SettingsScreen()
    }

    @Test("Profile Screen can be instantiated")
    func profileScreenCanBeInstantiated() {
        _ = ProfileScreen()
    }

    @Test("Info Screen can be instantiated")
    func infoScreenCanBeInstantiated() {
        let view = InfoScreen()
        let mirror = Mirror(reflecting: view)

        // Verify view exists
        #expect(mirror.children.count > 0)
    }

    @Test("ContentView can be instantiated")
    func contentViewCanBeInstantiated() {
        _ = ContentView()
    }

    // MARK: - Navigation Destination Tests

    @Test("NavigationDestination enum has comparison case with intervals")
    func navigationDestinationHasComparison() {
        let destination = NavigationDestination.comparison(intervals: [.prime])
        #expect(destination == NavigationDestination.comparison(intervals: [.prime]))
    }

    @Test("NavigationDestination enum has pitchMatching case with intervals")
    func navigationDestinationHasPitchMatching() {
        let destination = NavigationDestination.pitchMatching(intervals: [.prime])
        #expect(destination == NavigationDestination.pitchMatching(intervals: [.prime]))
    }

    @Test("NavigationDestination enum has settings case")
    func navigationDestinationHasSettings() {
        let destination = NavigationDestination.settings
        #expect(destination == NavigationDestination.settings)
    }

    @Test("NavigationDestination enum has profile case")
    func navigationDestinationHasProfile() {
        let destination = NavigationDestination.profile
        #expect(destination == NavigationDestination.profile)
    }

    @Test("NavigationDestination enum is Hashable")
    func navigationDestinationIsHashable() {
        let destination1 = NavigationDestination.comparison(intervals: [.prime])
        let destination2 = NavigationDestination.comparison(intervals: [.prime])
        let destination3 = NavigationDestination.settings

        #expect(destination1.hashValue == destination2.hashValue)
        #expect(destination1.hashValue != destination3.hashValue)
    }

    @Test("NavigationDestination comparison cases with different intervals are not equal")
    func navigationDestinationComparisonDifferentIntervals() {
        let unison = NavigationDestination.comparison(intervals: [.prime])
        let fifth = NavigationDestination.comparison(intervals: [.up(.perfectFifth)])
        #expect(unison != fifth)
    }

    @Test("NavigationDestination pitchMatching cases with different intervals are not equal")
    func navigationDestinationPitchMatchingDifferentIntervals() {
        let unison = NavigationDestination.pitchMatching(intervals: [.prime])
        let fifth = NavigationDestination.pitchMatching(intervals: [.up(.perfectFifth)])
        #expect(unison != fifth)
    }

    @Test("NavigationDestination cases are not equal when different")
    func navigationDestinationCasesAreDistinct() {
        #expect(NavigationDestination.comparison(intervals: [.prime]) != NavigationDestination.settings)
        #expect(NavigationDestination.settings != NavigationDestination.profile)
        #expect(NavigationDestination.comparison(intervals: [.prime]) != NavigationDestination.profile)
        #expect(NavigationDestination.comparison(intervals: [.prime]) != NavigationDestination.pitchMatching(intervals: [.prime]))
    }

    // MARK: - Info Screen Content Tests

    @Test("Info Screen has correct GitHub URL")
    func infoScreenHasCorrectGitHubURL() {
        #expect(InfoScreen.gitHubURL == URL(string: "https://github.com/mschuerig/peach")!)
    }

    @Test("Info Screen has correct developer name")
    func infoScreenHasCorrectDeveloperName() {
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
    func infoScreenHasCorrectLicenseName() {
        #expect(InfoScreen.licenseName == "MIT")
    }

    @Test("Info Screen has SoundFont credit")
    func infoScreenHasSoundFontCredit() {
        #expect(InfoScreen.soundFontCredit == "GeneralUser GS by S. Christian Collins")
    }

    @Test("Info Screen has non-empty version string")
    func infoScreenHasNonEmptyVersion() {
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

    @Test("Info Screen has four training modes with dash-separated names")
    func infoScreenHasFourTrainingModes() async {
        let modes = InfoScreen.trainingModes
        #expect(modes.count == 4)
        for mode in modes {
            #expect(mode.name.contains("–"))
        }
    }

    @Test("Info Screen training modes have non-empty names and descriptions")
    func infoScreenTrainingModesAreComplete() async {
        for mode in InfoScreen.trainingModes {
            #expect(!mode.name.isEmpty)
            #expect(!mode.description.isEmpty)
        }
    }

    @Test("Info Screen getting started text mentions Peach")
    func infoScreenHasGettingStarted() async {
        #expect(InfoScreen.gettingStartedText.contains("Peach"))
        #expect(InfoScreen.gettingStartedText.count > 30)
    }

    // MARK: - Hub and Spoke Pattern Verification

    @Test("All navigation destinations can be created")
    func allNavigationDestinationsCanBeCreated() {
        // Verify that all destination screens can be instantiated
        // This ensures the hub-and-spoke pattern has all spokes available

        let comparison = ComparisonScreen(intervals: [.prime])
        let intervalComparison = ComparisonScreen(intervals: [.up(.perfectFifth)])
        let pitchMatching = PitchMatchingScreen(intervals: [.prime])
        let intervalPitchMatching = PitchMatchingScreen(intervals: [.up(.perfectFifth)])
        let settings = SettingsScreen()
        let profile = ProfileScreen()
        let info = InfoScreen()

        // If we can create all screens without crashing, navigation paths are valid
        _ = (comparison, intervalComparison, pitchMatching, intervalPitchMatching, settings, profile, info)
    }
}

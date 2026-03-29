import Testing
@testable import Peach

@Suite("BackgroundPolicy")
struct BackgroundPolicyTests {

    // MARK: - IOSBackgroundPolicy

    @Test("iOS policy stops on background")
    func iosStopsOnBackground() async {
        let policy = IOSBackgroundPolicy()
        #expect(policy.shouldStopTraining(newPhase: .background))
    }

    @Test("iOS policy does not stop on inactive")
    func iosDoesNotStopOnInactive() async {
        let policy = IOSBackgroundPolicy()
        #expect(!policy.shouldStopTraining(newPhase: .inactive))
    }

    @Test("iOS policy does not stop on active")
    func iosDoesNotStopOnActive() async {
        let policy = IOSBackgroundPolicy()
        #expect(!policy.shouldStopTraining(newPhase: .active))
    }

    @Test("iOS policy clears navigation when returning from background")
    func iosClearsNavigationFromBackground() async {
        let policy = IOSBackgroundPolicy()
        #expect(policy.shouldClearNavigation(oldPhase: .background, newPhase: .active))
    }

    @Test("iOS policy clears navigation when returning from inactive")
    func iosClearsNavigationFromInactive() async {
        let policy = IOSBackgroundPolicy()
        #expect(policy.shouldClearNavigation(oldPhase: .inactive, newPhase: .active))
    }

    @Test("iOS policy does not clear navigation when not returning to active")
    func iosDoesNotClearNavigationOnBackground() async {
        let policy = IOSBackgroundPolicy()
        #expect(!policy.shouldClearNavigation(oldPhase: .active, newPhase: .background))
    }

    // MARK: - MacOSBackgroundPolicy

    @Test("macOS policy stops on background")
    func macosStopsOnBackground() async {
        let policy = MacOSBackgroundPolicy()
        #expect(policy.shouldStopTraining(newPhase: .background))
    }

    @Test("macOS policy stops on inactive")
    func macosStopsOnInactive() async {
        let policy = MacOSBackgroundPolicy()
        #expect(policy.shouldStopTraining(newPhase: .inactive))
    }

    @Test("macOS policy does not stop on active")
    func macosDoesNotStopOnActive() async {
        let policy = MacOSBackgroundPolicy()
        #expect(!policy.shouldStopTraining(newPhase: .active))
    }

    @Test("macOS policy does not clear navigation when returning from inactive")
    func macosDoesNotClearNavigationFromInactive() async {
        let policy = MacOSBackgroundPolicy()
        #expect(!policy.shouldClearNavigation(oldPhase: .inactive, newPhase: .active))
    }

    @Test("macOS policy does not clear navigation when returning from background")
    func macosDoesNotClearNavigationFromBackground() async {
        let policy = MacOSBackgroundPolicy()
        #expect(!policy.shouldClearNavigation(oldPhase: .background, newPhase: .active))
    }
}

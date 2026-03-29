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

    @Test("iOS policy auto-starts training")
    func iosAutoStartsTraining() {
        let policy = IOSBackgroundPolicy()
        #expect(policy.shouldAutoStartTraining)
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

    @Test("macOS policy does not auto-start training")
    func macosDoesNotAutoStartTraining() {
        let policy = MacOSBackgroundPolicy()
        #expect(!policy.shouldAutoStartTraining)
    }
}

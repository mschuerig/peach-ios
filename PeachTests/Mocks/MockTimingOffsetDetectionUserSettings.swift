import Foundation
@testable import Peach

final class MockTimingOffsetDetectionUserSettings: TimingOffsetDetectionUserSettings {
    var maxRepetitions: Int = TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions
}

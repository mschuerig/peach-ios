import Foundation
@testable import Peach

final class MockContinuousRhythmMatchingUserSettings: ContinuousRhythmMatchingUserSettings {
    var enabledGapPositions: Set<StepPosition> = ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions
}

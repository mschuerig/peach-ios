import Testing
import SwiftUI
@testable import Peach

@Suite("ProfilePreviewView Tests")
struct ProfilePreviewViewTests {

    // MARK: - Helpers

    private func makeTimeline(dailyOffsets: [Double]) -> ThresholdTimeline {
        let records = dailyOffsets.enumerated().map { index, offset in
            ComparisonRecord(
                referenceNote: 60,
                targetNote: 60,
                centOffset: offset,
                isCorrect: true,
                timestamp: Date().addingTimeInterval(Double(index - dailyOffsets.count) * 86400)
            )
        }
        return ThresholdTimeline(records: records)
    }

    // MARK: - Instantiation

    @Test("ProfilePreviewView can be instantiated in cold start state")
    func coldStartInstantiation() async throws {
        let _ = ProfilePreviewView()
    }

    // MARK: - Accessibility Labels

    @Test("Cold start accessibility label mentions training progress")
    func coldStartAccessibilityLabel() async throws {
        let label = ProfilePreviewView.accessibilityLabel(timeline: ThresholdTimeline())
        #expect(!label.isEmpty)
        #expect(label.localizedCaseInsensitiveContains("progress") || label.localizedCaseInsensitiveContains("training"),
                "Expected accessibility label to mention 'progress' or 'training', got: \(label)")
    }

    @Test("Trained state accessibility label includes current threshold value")
    func trainedAccessibilityLabel() async throws {
        // 3 days, each with offset 40 → aggregated mean per day = 40, rolling mean = 40
        let timeline = makeTimeline(dailyOffsets: [40, 40, 40])

        let label = ProfilePreviewView.accessibilityLabel(timeline: timeline)
        #expect(label.contains("40"),
                "Expected threshold value 40 in label, got: \(label)")
    }
}

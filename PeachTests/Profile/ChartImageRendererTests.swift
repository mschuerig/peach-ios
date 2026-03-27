import Testing
import Foundation
@testable import Peach

@Suite("ChartImageRenderer Tests")
@MainActor
struct ChartImageRendererTests {

    // MARK: - Export Filename

    @Test("export filename includes mode slug and formatted date")
    func exportFileNameFormat() async {
        let date = makeDate(year: 2026, month: 3, day: 15, hour: 14, minute: 32)
        let fileName = ChartImageRenderer.exportFileName(for: date, mode: .unisonPitchDiscrimination)
        #expect(fileName == "peach-pitch-discrimination-2026-03-15-1432.png")
    }

    @Test("export filename for interval comparison mode")
    func exportFileNameIntervalComparison() async {
        let date = makeDate(year: 2026, month: 3, day: 15, hour: 14, minute: 32)
        let fileName = ChartImageRenderer.exportFileName(for: date, mode: .intervalPitchDiscrimination)
        #expect(fileName == "peach-interval-discrimination-2026-03-15-1432.png")
    }

    @Test("export filename for pitch matching mode")
    func exportFileNamePitchMatching() async {
        let date = makeDate(year: 2026, month: 3, day: 15, hour: 14, minute: 32)
        let fileName = ChartImageRenderer.exportFileName(for: date, mode: .unisonPitchMatching)
        #expect(fileName == "peach-pitch-matching-2026-03-15-1432.png")
    }

    @Test("export filename for interval matching mode")
    func exportFileNameIntervalMatching() async {
        let date = makeDate(year: 2026, month: 3, day: 15, hour: 14, minute: 32)
        let fileName = ChartImageRenderer.exportFileName(for: date, mode: .intervalPitchMatching)
        #expect(fileName == "peach-interval-matching-2026-03-15-1432.png")
    }

    @Test("export filename uses en_US_POSIX locale regardless of device locale")
    func exportFileNameLocaleIndependent() async {
        // Use a date that would format differently in non-POSIX locales
        let date = makeDate(year: 2026, month: 1, day: 5, hour: 9, minute: 3)
        let fileName = ChartImageRenderer.exportFileName(for: date, mode: .unisonPitchDiscrimination)
        #expect(fileName == "peach-pitch-discrimination-2026-01-05-0903.png")
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)!
    }
}

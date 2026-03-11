import Testing
import Foundation
@testable import Peach

@Suite("GranularityZoneConfig Tests")
struct GranularityZoneConfigTests {

    // MARK: - Helpers

    private func abbreviatedMonthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func abbreviatedWeekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - MonthlyZoneConfig Tests

    @Test("monthly config returns expected pointWidth")
    func monthlyPointWidth() async {
        let config = MonthlyZoneConfig()
        #expect(config.pointWidth > 0)
    }

    @Test("monthly axis label formats as abbreviated month name")
    func monthlyAxisLabel() async {
        let config = MonthlyZoneConfig()
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = Calendar.current.date(from: components)!
        let label = config.axisLabelFormatter(date)
        #expect(label == abbreviatedMonthName(for: date))
    }

    @Test("monthly axis label produces different labels for different months")
    func monthlyAxisLabelVariousMonths() async {
        let config = MonthlyZoneConfig()
        let calendar = Calendar.current

        var janComponents = DateComponents()
        janComponents.year = 2026
        janComponents.month = 1
        janComponents.day = 15
        let janDate = calendar.date(from: janComponents)!

        var junComponents = DateComponents()
        junComponents.year = 2026
        junComponents.month = 6
        junComponents.day = 15
        let junDate = calendar.date(from: junComponents)!

        let janLabel = config.axisLabelFormatter(janDate)
        let junLabel = config.axisLabelFormatter(junDate)
        #expect(janLabel != junLabel)
        #expect(!janLabel.isEmpty)
        #expect(!junLabel.isEmpty)
    }

    // MARK: - DailyZoneConfig Tests

    @Test("daily config returns expected pointWidth")
    func dailyPointWidth() async {
        let config = DailyZoneConfig()
        #expect(config.pointWidth > 0)
    }

    @Test("daily axis label formats as abbreviated weekday name")
    func dailyAxisLabel() async {
        let config = DailyZoneConfig()
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 9
        let date = Calendar.current.date(from: components)!
        let label = config.axisLabelFormatter(date)
        #expect(label == abbreviatedWeekdayName(for: date))
    }

    @Test("daily axis label produces different labels for different weekdays")
    func dailyAxisLabelVariousDays() async {
        let config = DailyZoneConfig()
        let calendar = Calendar.current

        // Monday
        var monComponents = DateComponents()
        monComponents.year = 2026
        monComponents.month = 3
        monComponents.day = 9
        let monDate = calendar.date(from: monComponents)!

        // Friday
        var friComponents = DateComponents()
        friComponents.year = 2026
        friComponents.month = 3
        friComponents.day = 13
        let friDate = calendar.date(from: friComponents)!

        let monLabel = config.axisLabelFormatter(monDate)
        let friLabel = config.axisLabelFormatter(friDate)
        #expect(monLabel != friLabel)
        #expect(!monLabel.isEmpty)
        #expect(!friLabel.isEmpty)
    }

    // MARK: - SessionZoneConfig Tests

    @Test("session config returns expected pointWidth")
    func sessionPointWidth() async {
        let config = SessionZoneConfig()
        #expect(config.pointWidth > 0)
    }

    @Test("session axis label formats as time string")
    func sessionAxisLabel() async {
        let config = SessionZoneConfig()
        let now = Date()
        let label = config.axisLabelFormatter(now)
        #expect(!label.isEmpty)
    }

    // MARK: - Protocol Conformance Tests

    @Test("all configs conform to GranularityZoneConfig")
    func protocolConformance() async {
        let configs: [any GranularityZoneConfig] = [
            MonthlyZoneConfig(),
            DailyZoneConfig(),
            SessionZoneConfig(),
        ]
        for config in configs {
            #expect(config.pointWidth > 0)
        }
    }

    @Test("different zone configs have different pointWidths")
    func differentPointWidths() async {
        let monthly = MonthlyZoneConfig()
        let daily = DailyZoneConfig()
        let session = SessionZoneConfig()

        #expect(session.pointWidth >= daily.pointWidth)
        #expect(daily.pointWidth >= monthly.pointWidth)
    }
}

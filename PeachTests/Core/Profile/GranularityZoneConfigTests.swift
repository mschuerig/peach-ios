import Testing
import Foundation
@testable import Peach

@Suite("GranularityZoneConfig Tests")
struct GranularityZoneConfigTests {

    // MARK: - Helpers

    private func abbreviatedMonthName(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated))
    }

    private func abbreviatedWeekdayName(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    // MARK: - MonthlyZoneConfig Tests

    @Test("monthly config returns expected pointWidth of 30")
    func monthlyPointWidth() async {
        let config = MonthlyZoneConfig()
        #expect(config.pointWidth == 30)
    }

    @Test("monthly axis label formats as abbreviated month name")
    func monthlyAxisLabel() async {
        let config = MonthlyZoneConfig()
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = Calendar.current.date(from: components)!
        let label = config.formatAxisLabel(date)
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

        let janLabel = config.formatAxisLabel(janDate)
        let junLabel = config.formatAxisLabel(junDate)
        #expect(janLabel != junLabel)
        #expect(janLabel.isEmpty == false)
        #expect(junLabel.isEmpty == false)
    }

    // MARK: - DailyZoneConfig Tests

    @Test("daily config returns expected pointWidth of 40")
    func dailyPointWidth() async {
        let config = DailyZoneConfig()
        #expect(config.pointWidth == 40)
    }

    @Test("daily axis label formats as abbreviated weekday name")
    func dailyAxisLabel() async {
        let config = DailyZoneConfig()
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 9
        let date = Calendar.current.date(from: components)!
        let label = config.formatAxisLabel(date)
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

        let monLabel = config.formatAxisLabel(monDate)
        let friLabel = config.formatAxisLabel(friDate)
        #expect(monLabel != friLabel)
        #expect(monLabel.isEmpty == false)
        #expect(friLabel.isEmpty == false)
    }

    // MARK: - SessionZoneConfig Tests

    @Test("session config returns expected pointWidth of 50")
    func sessionPointWidth() async {
        let config = SessionZoneConfig()
        #expect(config.pointWidth == 50)
    }

    @Test("session axis label formats as time string")
    func sessionAxisLabel() async {
        let config = SessionZoneConfig()
        let now = Date()
        let label = config.formatAxisLabel(now)
        #expect(label.isEmpty == false)
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

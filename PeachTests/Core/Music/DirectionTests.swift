import Testing
import Foundation
@testable import Peach

@Suite("Direction Tests")
struct DirectionTests {

    // MARK: - Raw Values

    @Test("up has rawValue 0")
    func upRawValue() async {
        #expect(Direction.up.rawValue == 0)
    }

    @Test("down has rawValue 1")
    func downRawValue() async {
        #expect(Direction.down.rawValue == 1)
    }

    // MARK: - CaseIterable

    @Test("CaseIterable gives 2 cases")
    func caseIterableCount() async {
        #expect(Direction.allCases.count == 2)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() async throws {
        for direction in Direction.allCases {
            let data = try JSONEncoder().encode(direction)
            let decoded = try JSONDecoder().decode(Direction.self, from: data)
            #expect(decoded == direction)
        }
    }

    // MARK: - Comparable

    @Test("up is less than down")
    func upLessThanDown() async {
        #expect(Direction.up < Direction.down)
    }

    // MARK: - Display Name

    @Test("up displayName returns localized Up")
    func upDisplayName() async {
        #expect(Direction.up.displayName == String(localized: "Up"))
    }

    @Test("down displayName returns localized Down")
    func downDisplayName() async {
        #expect(Direction.down.displayName == String(localized: "Down"))
    }
}

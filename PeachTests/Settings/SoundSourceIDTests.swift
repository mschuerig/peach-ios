import Testing
@testable import Peach

@Suite("SoundSourceID Tests")
struct SoundSourceIDTests {

    // MARK: - Valid Construction

    @Test("Stores string value")
    func storesValue() async {
        let id = SoundSourceID("sf2:8:80")
        #expect(id.rawValue == "sf2:8:80")
    }

    // MARK: - ExpressibleByStringLiteral

    @Test("String literal creates SoundSourceID")
    func stringLiteral() async {
        let id: SoundSourceID = "sf2:0:0"
        #expect(id.rawValue == "sf2:0:0")
    }

    // MARK: - Hashable

    @Test("Equal IDs have same hash")
    func hashable() async {
        let set: Set<SoundSourceID> = [SoundSourceID("sf2:8:80"), SoundSourceID("sf2:8:80"), SoundSourceID("sf2:0:0")]
        #expect(set.count == 2)
    }

    // MARK: - Equality

    @Test("Same strings are equal")
    func equality() async {
        #expect(SoundSourceID("sf2:8:80") == SoundSourceID("sf2:8:80"))
    }

    @Test("Different strings are not equal")
    func inequality() async {
        #expect(SoundSourceID("sf2:8:80") != SoundSourceID("sf2:0:0"))
    }
}

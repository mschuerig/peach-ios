import Testing
@testable import Peach

@Suite("MIDIChannel Tests")
struct MIDIChannelTests {

    @Test("Creates channel with valid value")
    func validChannel() {
        let channel = MIDIChannel(0)
        #expect(channel.rawValue == 0)
    }

    @Test("Creates channel at upper bound")
    func upperBound() {
        let channel = MIDIChannel(15)
        #expect(channel.rawValue == 15)
    }

    @Test("Supports integer literal initialization")
    func integerLiteral() {
        let channel: MIDIChannel = 9
        #expect(channel.rawValue == 9)
    }

    @Test("Channels with same value are equal")
    func equality() {
        #expect(MIDIChannel(5) == MIDIChannel(5))
    }

    @Test("Channels with different values are not equal")
    func inequality() {
        #expect(MIDIChannel(0) != MIDIChannel(15))
    }
}

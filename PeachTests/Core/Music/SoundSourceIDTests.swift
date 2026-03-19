import Testing
@testable import Peach

@Suite("SoundSourceID Tests")
struct SoundSourceIDTests {

    // MARK: - Protocol Contract via SF2Preset

    @Test("SF2Preset rawValue encodes bank and program")
    func rawValueEncoding() async {
        let preset = SF2Preset(name: "Cello", program: 42, bank: 0)
        #expect(preset.rawValue == "sf2:0:42")
    }

    @Test("SF2Preset displayName returns preset name")
    func displayName() async {
        let preset = SF2Preset(name: "Grand Piano", program: 0, bank: 0)
        #expect(preset.displayName == "Grand Piano")
    }

    @Test("SF2Preset conforms to SoundSourceID")
    func conformsToProtocol() async {
        let preset = SF2Preset(name: "Cello", program: 42, bank: 0)
        let source: any SoundSourceID = preset
        #expect(source.rawValue == "sf2:0:42")
        #expect(source.displayName == "Cello")
    }

    @Test("Different SF2Presets produce different rawValues")
    func differentRawValues() async {
        let a = SF2Preset(name: "Cello", program: 42, bank: 0)
        let b = SF2Preset(name: "Sine Wave", program: 80, bank: 8)
        #expect(a.rawValue != b.rawValue)
    }

    @Test("SF2Preset Hashable uses name, program, and bank")
    func hashable() async {
        let set: Set<SF2Preset> = [
            SF2Preset(name: "Cello", program: 42, bank: 0),
            SF2Preset(name: "Cello", program: 42, bank: 0),
            SF2Preset(name: "Piano", program: 0, bank: 0)
        ]
        #expect(set.count == 2)
    }
}

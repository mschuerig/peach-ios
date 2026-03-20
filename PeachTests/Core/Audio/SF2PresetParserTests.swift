import Testing
import Foundation
@testable import Peach

@Suite("SF2PresetParser Tests")
struct SF2PresetParserTests {

    // MARK: - Parsing Bundled SF2

    @Test("Parses bundled SF2 and returns non-empty preset list")
    func parsesBundledSF2() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        #expect(!presets.isEmpty)
    }

    @Test("Preset count matches expected total (150 presets)")
    func presetCountMatchesExpected() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        // Custom Samples.sf2: 149 pitched + 1 percussion preset
        #expect(presets.count == 150)
    }

    @Test("Yamaha Grand Piano found at bank 0, program 0")
    func findsGrandPiano() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        let piano = presets.first { $0.program == 0 && $0.bank == 0 }
        #expect(piano != nil)
        #expect(piano?.name == "Yamaha Grand Piano")
    }

    @Test("Cello found at bank 0, program 42")
    func findsCello() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        let cello = presets.first { $0.program == 42 && $0.bank == 0 }
        #expect(cello != nil)
        #expect(cello?.name == "Cello")
    }

    @Test("Bank variants found (e.g., bank 8 program 6 Coupled Harpsichord)")
    func findsBankVariants() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        let variant = presets.first { $0.bank == 8 && $0.program == 6 }
        #expect(variant != nil)
        #expect(variant?.name == "Coupled Harpsichord")
    }

    // MARK: - EOP Sentinel Exclusion

    @Test("EOP sentinel record is not in the result")
    func excludesEOPSentinel() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        let eop = presets.filter { $0.name == "EOP" || $0.name.hasPrefix("EOP") }
        #expect(eop.isEmpty)
    }

    // MARK: - Name Cleaning

    @Test("Preset names have no trailing null bytes")
    func namesHaveNoNullBytes() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        for preset in presets {
            #expect(!preset.name.contains("\0"), "Preset '\(preset.name)' contains null bytes")
        }
    }

    @Test("Preset names have no leading or trailing whitespace")
    func namesAreTrimmed() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        for preset in presets {
            #expect(preset.name == preset.name.trimmingCharacters(in: .whitespaces),
                    "Preset '\(preset.name)' has untrimmed whitespace")
        }
    }

    // MARK: - Error Handling

    @Test("Throws for missing file")
    func throwsForMissingFile() async {
        let bogusURL = URL(fileURLWithPath: "/nonexistent/file.sf2")
        #expect(throws: SF2ParseError.self) {
            _ = try SF2PresetParser.parsePresets(from: bogusURL)
        }
    }

    // MARK: - SoundSourceID Conformance

    @Test("SF2Preset rawValue encodes bank and program")
    func rawValueEncodesBankAndProgram() async {
        let preset = SF2Preset(name: "Cello", program: 42, bank: 0)
        #expect(preset.rawValue == "sf2:0:42")

        let variant = SF2Preset(name: "Acid Bass", program: 38, bank: 8)
        #expect(variant.rawValue == "sf2:8:38")
    }

    // MARK: - MIDI Constants

    @Test("percussionBank is 128")
    func percussionBankConstant() async {
        #expect(SF2Preset.percussionBank == 128)
    }

    @Test("melodicBankMSB is 0x79")
    func melodicBankMSBConstant() async {
        #expect(SF2Preset.melodicBankMSB == 0x79)
    }

    @Test("percussionBankMSB is 0x78")
    func percussionBankMSBConstant() async {
        #expect(SF2Preset.percussionBankMSB == 0x78)
    }

    @Test("isPercussion returns true for bank 128")
    func isPercussionBank128() async {
        let preset = SF2Preset(name: "Standard Drums", program: 0, bank: 128)
        #expect(preset.isPercussion)
    }

    @Test("isPercussion returns false for bank 0")
    func isNotPercussionBank0() async {
        let preset = SF2Preset(name: "Piano", program: 0, bank: 0)
        #expect(!preset.isPercussion)
    }

    @Test("bankMSB returns percussionBankMSB for percussion preset")
    func bankMSBPercussion() async {
        let preset = SF2Preset(name: "Standard Drums", program: 0, bank: 128)
        #expect(preset.bankMSB == SF2Preset.percussionBankMSB)
    }

    @Test("bankMSB returns melodicBankMSB for melodic preset")
    func bankMSBMelodic() async {
        let preset = SF2Preset(name: "Piano", program: 0, bank: 0)
        #expect(preset.bankMSB == SF2Preset.melodicBankMSB)
    }

    // MARK: - Helpers

    private func sf2URL() throws -> URL {
        TestSoundFont.url
    }
}

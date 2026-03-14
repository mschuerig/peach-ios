import Testing
import Foundation
@testable import Peach

@Suite("SF2PresetParser Tests")
struct SF2PresetParserTests {

    // MARK: - Parsing Bundled SF2

    @Test("Parses GeneralUser GS SF2 and returns non-empty preset list")
    func parsesGeneralUserSF2() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        #expect(!presets.isEmpty)
    }

    @Test("Preset count matches expected GeneralUser GS total (287 presets)")
    func presetCountMatchesExpected() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        // GeneralUser GS: 261 melodic + 13 drum kits (bank 120) + 13 drums (bank 128) = 287
        #expect(presets.count == 287)
    }

    @Test("Grand Piano found at bank 0, program 0")
    func findsGrandPiano() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        let piano = presets.first { $0.program == 0 && $0.bank == 0 }
        #expect(piano != nil)
        #expect(piano?.name == "Grand Piano")
    }

    @Test("Cello found at bank 0, program 42")
    func findsCello() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        let cello = presets.first { $0.program == 42 && $0.bank == 0 }
        #expect(cello != nil)
        #expect(cello?.name == "Cello")
    }

    @Test("Bank variants found (e.g., bank 8 program 4 Chorused Tine EP)")
    func findsBankVariants() async throws {
        let url = try sf2URL()
        let presets = try SF2PresetParser.parsePresets(from: url)
        let variant = presets.first { $0.bank == 8 && $0.program == 4 }
        #expect(variant != nil)
        #expect(variant?.name == "Chorused Tine EP")
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

    // MARK: - Helpers

    private func sf2URL() throws -> URL {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "GeneralUser-GS", withExtension: "sf2") else {
            guard let mainURL = Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2") else {
                throw SF2ParseError.fileNotReadable
            }
            return mainURL
        }
        return url
    }
}

private final class BundleToken {}

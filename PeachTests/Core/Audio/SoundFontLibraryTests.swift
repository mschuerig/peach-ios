import Testing
import Foundation
@testable import Peach

@Suite("SoundFontLibrary Tests")
struct SoundFontLibraryTests {

    private func makeLibrary() -> SoundFontLibrary {
        TestSoundFont.makeLibrary()
    }

    // MARK: - Preset Discovery

    @Test("Discovers presets from explicit SF2 URL")
    func discoversPresetsFromURL() async {
        let library = makeLibrary()
        #expect(!library.melodicPresets.isEmpty)
    }

    @Test("Excludes drum kits (bank >= 120)")
    func noDrumKitsInAvailablePresets() async {
        let library = makeLibrary()
        let drumPresets = library.melodicPresets.filter { $0.bank >= 120 }
        #expect(drumPresets.isEmpty)
    }

    @Test("Excludes sound effects (program >= 120)")
    func noSoundEffectsInAvailablePresets() async {
        let library = makeLibrary()
        let sfxPresets = library.melodicPresets.filter { $0.program >= 120 }
        #expect(sfxPresets.isEmpty)
    }

    @Test("Presets sorted alphabetically by name")
    func presetsSortedAlphabetically() async {
        let library = makeLibrary()
        let names = library.melodicPresets.map(\.name)
        let sorted = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        #expect(names == sorted)
    }

    @Test("Contains Yamaha Grand Piano at bank 0 program 0")
    func containsPiano() async {
        let library = makeLibrary()
        let piano = library.melodicPresets.first { $0.program == 0 && $0.bank == 0 }
        #expect(piano != nil)
        #expect(piano?.name == "Yamaha Grand Piano")
    }

    @Test("Contains Cello at bank 0 program 42")
    func containsCello() async {
        let library = makeLibrary()
        let cello = library.melodicPresets.first { $0.program == 42 && $0.bank == 0 }
        #expect(cello != nil)
        #expect(cello?.name == "Cello")
    }

    @Test("Contains bank variants (e.g., bank 8 program 6)")
    func containsBankVariants() async {
        let library = makeLibrary()
        let variant = library.melodicPresets.first { $0.bank == 8 && $0.program == 6 }
        #expect(variant != nil)
        #expect(variant?.name == "Coupled Harpsichord")
    }

    // MARK: - SoundSourceProvider Conformance

    @Test("SoundFontLibrary conforms to SoundSourceProvider")
    func conformsToSoundSourceProvider() async {
        let library = makeLibrary()
        #expect(library is SoundSourceProvider)
    }

    @Test("availableSources via protocol matches stored presets count")
    func protocolSourcesMatchStored() async {
        let library = makeLibrary()
        let provider: any SoundSourceProvider = library
        #expect(provider.availableSources.count == library.melodicPresets.count)
    }

    @Test("Cello preset has correct rawValue")
    func celloPresetRawValue() async {
        let library = makeLibrary()
        let cello = library.melodicPresets.first { $0.program == 42 && $0.bank == 0 }
        #expect(cello?.rawValue == "sf2:0:42")
    }

    @Test("Preset displayName is accessible directly from SF2Preset")
    func presetDisplayNameAccessible() async {
        let library = makeLibrary()
        let cello = library.melodicPresets.first { $0.rawValue == "sf2:0:42" }
        #expect(cello?.displayName == "Cello")
    }

    // MARK: - No Duplicate Raw Values

    @Test("All preset rawValues are unique")
    func allRawValuesUnique() async {
        let library = makeLibrary()
        let rawValues = library.melodicPresets.map(\.rawValue)
        let uniqueRawValues = Set(rawValues)
        #expect(rawValues.count == uniqueRawValues.count)
    }

    // MARK: - Resolve

    @Test("resolve returns SF2Preset for valid preset")
    func resolveValidPreset() async {
        let library = makeLibrary()
        let result = library.resolve(SoundSourceTag(rawValue: "sf2:0:42"))
        #expect(result.bank == 0)
        #expect(result.program == 42)
        #expect(result.name == "Cello")
    }

    @Test("resolve falls back to default for unparseable string")
    func resolveFallbackForGarbage() async {
        let library = makeLibrary()
        let result = library.resolve(SoundSourceTag(rawValue: "garbage"))
        #expect(result.bank == 0)
        #expect(result.program == 0)
    }

    @Test("resolve falls back to default for unknown preset")
    func resolveFallbackForUnknown() async {
        let library = makeLibrary()
        let result = library.resolve(SoundSourceTag(rawValue: "sf2:99:99"))
        #expect(result.bank == 0)
        #expect(result.program == 0)
    }

    @Test("resolve falls back to default for empty string")
    func resolveFallbackForEmpty() async {
        let library = makeLibrary()
        let result = library.resolve(SoundSourceTag(rawValue: ""))
        #expect(result.bank == 0)
        #expect(result.program == 0)
    }

    @Test("sf2URL is exposed from library")
    func sf2URLExposed() async {
        let library = makeLibrary()
        #expect(library.sf2URL == TestSoundFont.url)
    }

    // MARK: - melodicPresets

    @Test("melodicPresets contains no percussion presets")
    func melodicPresetsExcludesPercussion() async {
        let library = makeLibrary()
        let percussion = library.melodicPresets.filter { $0.isPercussion }
        #expect(percussion.isEmpty)
    }

    @Test("melodicPresets equals availableSources count")
    func melodicPresetsMatchesAvailableSources() async {
        let library = makeLibrary()
        #expect(library.melodicPresets.count == library.availableSources.count)
    }

    // MARK: - percussionPresets

    @Test("percussionPresets contains only percussion bank presets")
    func percussionPresetsOnlyPercussion() async {
        let library = makeLibrary()
        for preset in library.percussionPresets {
            #expect(preset.isPercussion, "Expected percussion preset, got bank \(preset.bank)")
        }
    }

    // MARK: - resolvePercussion

    @Test("resolvePercussion returns nil for unknown soundSource")
    func resolvePercussionUnknown() async {
        let library = makeLibrary()
        let result = library.resolvePercussion(SoundSourceTag(rawValue: "sf2:128:99"))
        #expect(result == nil)
    }
}

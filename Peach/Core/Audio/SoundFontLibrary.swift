import Foundation
import os

final class SoundFontLibrary: SoundSourceProvider {

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontLibrary")

    let sf2URL: URL
    private(set) var availablePresets: [SF2Preset]
    private let defaultPreset: SF2Preset

    var availableSources: [any SoundSourceID] { availablePresets }

    init(sf2URL: URL, defaultPreset: String) {
        self.sf2URL = sf2URL

        var presets: [SF2Preset] = []

        do {
            let allPresets = try SF2PresetParser.parsePresets(from: sf2URL)
            let pitched = allPresets.filter { $0.bank < 120 && $0.program < 120 }
            presets.append(contentsOf: pitched)
        } catch {
            logger.warning("Failed to parse SF2 at \(sf2URL.lastPathComponent): \(error)")
        }

        presets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.availablePresets = presets
        self.defaultPreset = Self.findPreset(rawValue: defaultPreset, in: presets)
            ?? presets.first
            ?? SF2Preset(name: "", program: 0, bank: 0)

        logger.info("SoundFontLibrary initialized with \(presets.count) pitched presets")
    }

    // MARK: - Preset Resolution

    func resolve(_ soundSource: any SoundSourceID) -> SF2Preset {
        Self.findPreset(rawValue: soundSource.rawValue, in: availablePresets) ?? defaultPreset
    }

    // MARK: - Private

    private static func findPreset(rawValue: String, in presets: [SF2Preset]) -> SF2Preset? {
        guard let components = parseSF2Components(rawValue) else { return nil }
        return presets.first(where: { $0.bank == components.bank && $0.program == components.program })
    }

    private static func parseSF2Components(_ rawValue: String) -> (bank: Int, program: Int)? {
        guard rawValue.hasPrefix("sf2:") else { return nil }
        let parts = rawValue.dropFirst(4).split(separator: ":")
        guard parts.count == 2,
              let bank = Int(parts[0]),
              let program = Int(parts[1]) else { return nil }
        return (bank: bank, program: program)
    }
}

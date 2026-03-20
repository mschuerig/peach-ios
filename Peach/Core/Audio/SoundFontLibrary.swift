import Foundation
import os

final class SoundFontLibrary: SoundSourceProvider {

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontLibrary")

    let sf2URL: URL
    private(set) var melodicPresets: [SF2Preset]
    private(set) var percussionPresets: [SF2Preset]
    private let defaultPreset: SF2Preset

    var availableSources: [any SoundSourceID] { melodicPresets }

    init(sf2URL: URL, defaultPreset: String) {
        self.sf2URL = sf2URL

        var melodic: [SF2Preset] = []
        var percussion: [SF2Preset] = []

        do {
            let allPresets = try SF2PresetParser.parsePresets(from: sf2URL)
            for preset in allPresets {
                if preset.isPercussion {
                    percussion.append(preset)
                } else {
                    melodic.append(preset)
                }
            }
        } catch {
            logger.warning("Failed to parse SF2 at \(sf2URL.lastPathComponent): \(error)")
        }

        melodic.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        percussion.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.melodicPresets = melodic
        self.percussionPresets = percussion
        self.defaultPreset = Self.findPreset(rawValue: defaultPreset, in: melodic)
            ?? melodic.first
            ?? SF2Preset(name: "", program: 0, bank: 0)

        logger.info("SoundFontLibrary initialized with \(melodic.count) melodic, \(percussion.count) percussion presets")
    }

    // MARK: - Preset Resolution

    func resolve(_ soundSource: any SoundSourceID) -> SF2Preset {
        Self.findPreset(rawValue: soundSource.rawValue, in: melodicPresets) ?? defaultPreset
    }

    func resolvePercussion(_ soundSource: any SoundSourceID) -> SF2Preset? {
        Self.findPreset(rawValue: soundSource.rawValue, in: percussionPresets)
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

import Foundation
import os

final class SoundFontLibrary: SoundSourceProvider {

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontLibrary")

    let sf2URL: URL
    private(set) var availablePresets: [SF2Preset]
    private let defaultBank: Int
    private let defaultProgram: Int

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

        if let components = Self.parseSF2Components(defaultPreset) {
            self.defaultBank = components.bank
            self.defaultProgram = components.program
        } else {
            self.defaultBank = 0
            self.defaultProgram = 0
        }

        logger.info("SoundFontLibrary initialized with \(presets.count) pitched presets")
    }

    // MARK: - Preset Resolution

    func resolve(_ rawValue: String) -> (bank: Int, program: Int) {
        if let components = Self.parseSF2Components(rawValue),
           availablePresets.contains(where: { $0.bank == components.bank && $0.program == components.program }) {
            return components
        }
        return (bank: defaultBank, program: defaultProgram)
    }

    // MARK: - Private

    private static func parseSF2Components(_ rawValue: String) -> (bank: Int, program: Int)? {
        guard rawValue.hasPrefix("sf2:") else { return nil }
        let parts = rawValue.dropFirst(4).split(separator: ":")
        guard parts.count == 2,
              let bank = Int(parts[0]),
              let program = Int(parts[1]) else { return nil }
        return (bank: bank, program: program)
    }
}

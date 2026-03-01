import Foundation
import os

final class SoundFontLibrary {

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontLibrary")

    let availablePresets: [SF2Preset]

    init(bundle: Bundle = .main) {
        var presets: [SF2Preset] = []

        if let sf2URLs = bundle.urls(forResourcesWithExtension: "sf2", subdirectory: nil) {
            for url in sf2URLs {
                do {
                    let allPresets = try SF2PresetParser.parsePresets(from: url)
                    let pitched = allPresets.filter { $0.bank < 120 && $0.program < 120 }
                    presets.append(contentsOf: pitched)
                } catch {
                    Logger(subsystem: "com.peach.app", category: "SoundFontLibrary")
                        .warning("Failed to parse SF2 at \(url.lastPathComponent): \(error)")
                }
            }
        }

        presets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.availablePresets = presets

        logger.info("SoundFontLibrary initialized with \(presets.count) pitched presets")
    }

    func preset(forTag tag: String) -> SF2Preset? {
        guard tag.hasPrefix("sf2:") else { return nil }
        let parts = tag.dropFirst(4).split(separator: ":")
        guard parts.count == 2,
              let bank = Int(parts[0]),
              let program = Int(parts[1]) else { return nil }
        return availablePresets.first { $0.bank == bank && $0.program == program }
    }
}

// MARK: - SoundSourceProvider

extension SoundFontLibrary: SoundSourceProvider {
    var availableSources: [SoundSourceID] {
        availablePresets.map { SoundSourceID($0.tag) }
    }

    func displayName(for source: SoundSourceID) -> String {
        preset(forTag: source.rawValue)?.name ?? source.rawValue
    }
}

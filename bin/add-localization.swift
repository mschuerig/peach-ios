#!/usr/bin/env swift
//
// bin/add-localization.swift — Add German localization entries to Localizable.xcstrings.
//
// Usage:
//   # Single entry
//   bin/add-localization.swift "Settings" "Einstellungen"
//
//   # Batch from JSON file (object with "key": "German translation")
//   bin/add-localization.swift --batch translations.json
//
//   # Batch from CSV (key,translation per line, no header)
//   bin/add-localization.swift --batch translations.csv
//
//   # List existing keys
//   bin/add-localization.swift --list
//
//   # Show entries missing a German translation
//   bin/add-localization.swift --missing
//
//   # Dry run
//   bin/add-localization.swift --dry-run "Settings" "Einstellungen"
//
// Options:
//   --xcstrings PATH    Path to .xcstrings file (default: auto-detect)
//   --batch FILE        Read translations from JSON or CSV file
//   --list              List all existing keys and German translations
//   --missing           Show keys without German translations
//   --dry-run           Show changes without writing

import Foundation

// MARK: - File Discovery

func findXCStrings() -> URL? {
    let fileManager = FileManager.default
    let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    let candidates = [
        "Peach/Resources/Localizable.xcstrings",
        "Resources/Localizable.xcstrings",
        "Localizable.xcstrings",
    ]

    // Try relative to cwd
    for candidate in candidates {
        let url = cwd.appendingPathComponent(candidate)
        if fileManager.fileExists(atPath: url.path) {
            return url
        }
    }

    // Try relative to script location
    let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    for candidate in candidates {
        let url = scriptDir.appendingPathComponent(candidate)
        if fileManager.fileExists(atPath: url.path) {
            return url
        }
    }

    return nil
}

// MARK: - Xcode-Compatible JSON Encoding

func xcodeJSONEncode(_ value: Any, indent: Int = 0) -> String {
    let prefix = String(repeating: " ", count: indent)

    if let dict = value as? [String: Any] {
        if dict.isEmpty {
            return "{\n\n\(prefix)}"
        }
        let sortedKeys = dict.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        var items: [String] = []
        for key in sortedKeys {
            let encodedKey = jsonEncodeString(key)
            let encodedValue = xcodeJSONEncode(dict[key]!, indent: indent + 2)
            items.append("\(prefix)  \(encodedKey) : \(encodedValue)")
        }
        return "{\n" + items.joined(separator: ",\n") + "\n\(prefix)}"
    }

    if let array = value as? [Any] {
        if array.isEmpty {
            return "[]"
        }
        var items: [String] = []
        for element in array {
            let encodedValue = xcodeJSONEncode(element, indent: indent + 2)
            items.append("\(prefix)  \(encodedValue)")
        }
        return "[\n" + items.joined(separator: ",\n") + "\n\(prefix)]"
    }

    if let string = value as? String {
        return jsonEncodeString(string)
    }

    if let number = value as? NSNumber {
        if number === kCFBooleanTrue {
            return "true"
        }
        if number === kCFBooleanFalse {
            return "false"
        }
        if number is Int {
            return "\(number.intValue)"
        }
        return "\(number.doubleValue)"
    }

    if value is NSNull {
        return "null"
    }

    return "\(value)"
}

func jsonEncodeString(_ string: String) -> String {
    var result = "\""
    for char in string.unicodeScalars {
        switch char {
        case "\"": result += "\\\""
        case "\\": result += "\\\\"
        case "\n": result += "\\n"
        case "\r": result += "\\r"
        case "\t": result += "\\t"
        case "\u{08}": result += "\\b"
        case "\u{0C}": result += "\\f"
        default:
            if char.value < 0x20 {
                result += String(format: "\\u%04x", char.value)
            } else {
                result += String(char)
            }
        }
    }
    result += "\""
    return result
}

// MARK: - XCStrings I/O

func loadXCStrings(from url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw NSError(domain: "add-localization", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Invalid xcstrings format: root must be a JSON object"
        ])
    }
    return dict
}

func saveXCStrings(_ data: [String: Any], to url: URL) throws {
    let output = xcodeJSONEncode(data)
    try output.write(to: url, atomically: true, encoding: .utf8)
}

// MARK: - Translation Operations

func getGermanValue(from entry: [String: Any]) -> String? {
    guard let localizations = entry["localizations"] as? [String: Any],
          let de = localizations["de"] as? [String: Any],
          let stringUnit = de["stringUnit"] as? [String: Any],
          let value = stringUnit["value"] as? String else {
        return nil
    }
    return value
}

func makeEntry(germanValue: String) -> [String: Any] {
    [
        "localizations": [
            "de": [
                "stringUnit": [
                    "state": "translated",
                    "value": germanValue,
                ]
            ]
        ]
    ]
}

struct TranslationResult {
    var added = 0
    var updated = 0
    var skipped = 0
}

func addTranslations(
    to data: inout [String: Any],
    translations: [(key: String, german: String)],
    dryRun: Bool
) -> TranslationResult {
    var strings = data["strings"] as? [String: Any] ?? [:]
    var result = TranslationResult()

    for (key, german) in translations {
        if var entry = strings[key] as? [String: Any] {
            let existingDE = getGermanValue(from: entry)

            if existingDE == german {
                result.skipped += 1
                if dryRun {
                    print("  skip (identical): \(quoted(key))")
                }
                continue
            }

            // Update existing entry, preserving other localizations
            var localizations = entry["localizations"] as? [String: Any] ?? [:]
            localizations["de"] = [
                "stringUnit": [
                    "state": "translated",
                    "value": german,
                ]
            ]
            entry["localizations"] = localizations
            strings[key] = entry
            result.updated += 1
            if dryRun {
                let old = existingDE ?? "(none)"
                print("  update: \(quoted(key)): \(quoted(old)) → \(quoted(german))")
            }
        } else {
            strings[key] = makeEntry(germanValue: german)
            result.added += 1
            if dryRun {
                print("  add: \(quoted(key)) → \(quoted(german))")
            }
        }
    }

    data["strings"] = strings
    return result
}

// MARK: - Batch Loading

func parseCSVLine(_ line: String, delimiter: Character) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    var i = line.startIndex

    while i < line.endIndex {
        let char = line[i]
        if inQuotes {
            if char == "\"" {
                let next = line.index(after: i)
                if next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                } else {
                    inQuotes = false
                    i = line.index(after: i)
                }
            } else {
                current.append(char)
                i = line.index(after: i)
            }
        } else if char == "\"" {
            inQuotes = true
            i = line.index(after: i)
        } else if char == delimiter {
            fields.append(current)
            current = ""
            i = line.index(after: i)
        } else {
            current.append(char)
            i = line.index(after: i)
        }
    }
    fields.append(current)
    return fields
}

func loadBatchFile(from url: URL) throws -> [(key: String, german: String)] {
    if url.pathExtension == "json" {
        let data = try Data(contentsOf: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw NSError(domain: "add-localization", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "JSON file must be an object with {\"key\": \"translation\"}"
            ])
        }
        return dict.map { ($0.key, $0.value) }
    }

    // CSV/TSV — supports RFC 4180 quoted fields
    let content = try String(contentsOf: url, encoding: .utf8)
    let delimiter: Character = content.contains("\t") ? "\t" : ","
    var translations: [(String, String)] = []

    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }

        let fields = parseCSVLine(trimmed, delimiter: delimiter)
        guard fields.count >= 2 else { continue }

        let key = fields[0].trimmingCharacters(in: .whitespaces)
        let value = fields[1].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty else { continue }
        translations.append((key, value))
    }

    return translations
}

// MARK: - List / Missing

func listKeys(in data: [String: Any]) {
    guard let strings = data["strings"] as? [String: Any] else { return }
    let sortedKeys = strings.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }

    for key in sortedKeys {
        if let entry = strings[key] as? [String: Any],
           let de = getGermanValue(from: entry) {
            print("\(key)  →  \(de)")
        } else {
            print("\(key)  →  (no German translation)")
        }
    }
}

func showMissing(in data: [String: Any]) {
    guard let strings = data["strings"] as? [String: Any] else { return }
    let sortedKeys = strings.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    var count = 0

    for key in sortedKeys {
        if let entry = strings[key] as? [String: Any] {
            if getGermanValue(from: entry) == nil {
                print(key)
                count += 1
            }
        } else {
            print(key)
            count += 1
        }
    }

    printErr("\n\(count) keys missing German translation")
}

// MARK: - Helpers

func printErr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func quoted(_ s: String) -> String {
    "'\(s)'"
}

func exitWithError(_ message: String) -> Never {
    printErr("Error: \(message)")
    exit(1)
}

// MARK: - Argument Parsing

struct Arguments {
    var xcstringsPath: String?
    var batchFile: String?
    var list = false
    var missing = false
    var dryRun = false
    var key: String?
    var german: String?
}

func parseArguments() -> Arguments {
    var args = Arguments()
    let argv = Array(CommandLine.arguments.dropFirst())
    var i = 0

    while i < argv.count {
        switch argv[i] {
        case "--xcstrings":
            i += 1
            guard i < argv.count else { exitWithError("--xcstrings requires a path") }
            args.xcstringsPath = argv[i]
        case "--batch":
            i += 1
            guard i < argv.count else { exitWithError("--batch requires a file path") }
            args.batchFile = argv[i]
        case "--list":
            args.list = true
        case "--missing":
            args.missing = true
        case "--dry-run":
            args.dryRun = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            if argv[i].hasPrefix("-") {
                exitWithError("Unknown option: \(argv[i])")
            }
            if args.key == nil {
                args.key = argv[i]
            } else if args.german == nil {
                args.german = argv[i]
            } else {
                exitWithError("Too many positional arguments")
            }
        }
        i += 1
    }

    return args
}

func printUsage() {
    print("""
    Usage: add-localization.swift [OPTIONS] [KEY GERMAN]

    Add German localization entries to Localizable.xcstrings.

    Arguments:
      KEY                 Localization key (English string)
      GERMAN              German translation

    Options:
      --xcstrings PATH    Path to .xcstrings file (default: auto-detect)
      --batch FILE        Read translations from JSON or CSV file
      --list              List all existing keys and German translations
      --missing           Show keys without German translations
      --dry-run           Show changes without writing
      -h, --help          Show this help
    """)
}

// MARK: - Main

let args = parseArguments()

// Find xcstrings file
let xcstringsURL: URL
if let path = args.xcstringsPath {
    xcstringsURL = URL(fileURLWithPath: path)
} else if let found = findXCStrings() {
    xcstringsURL = found
} else {
    exitWithError("Could not find Localizable.xcstrings. Specify path with --xcstrings")
}

guard FileManager.default.fileExists(atPath: xcstringsURL.path) else {
    exitWithError("File not found: \(xcstringsURL.path)")
}

var data: [String: Any]
do {
    data = try loadXCStrings(from: xcstringsURL)
} catch {
    exitWithError("Failed to load \(xcstringsURL.lastPathComponent): \(error.localizedDescription)")
}

// List mode
if args.list {
    listKeys(in: data)
    exit(0)
}

// Missing mode
if args.missing {
    showMissing(in: data)
    exit(0)
}

// Collect translations
var translations: [(key: String, german: String)] = []

if let batchFile = args.batchFile {
    if args.key != nil {
        exitWithError("Cannot use --batch together with positional arguments.")
    }
    do {
        translations = try loadBatchFile(from: URL(fileURLWithPath: batchFile))
    } catch {
        exitWithError("Failed to load batch file: \(error.localizedDescription)")
    }
} else if let key = args.key, let german = args.german {
    translations = [(key, german)]
} else if args.key != nil {
    exitWithError("Missing German translation argument.")
} else {
    printUsage()
    exit(1)
}

guard !translations.isEmpty else {
    exitWithError("No translations to add.")
}

// Apply
if args.dryRun {
    print("Dry run against \(xcstringsURL.lastPathComponent):\n")
}

let result = addTranslations(to: &data, translations: translations, dryRun: args.dryRun)

if !args.dryRun {
    do {
        try saveXCStrings(data, to: xcstringsURL)
    } catch {
        exitWithError("Failed to write \(xcstringsURL.lastPathComponent): \(error.localizedDescription)")
    }
}

let action = args.dryRun ? "Would add" : "Added"
let total = translations.count
print("\n\(action) \(result.added), updated \(result.updated), skipped \(result.skipped) (of \(total) entries) in \(xcstringsURL.lastPathComponent)")

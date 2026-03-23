import Foundation

nonisolated enum CSVParserHelpers {

    // MARK: - RFC 4180 CSV Line Parsing

    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                fields.append(current)
                                current = ""
                            } else {
                                current.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
        }

        fields.append(current)
        return fields
    }

    // MARK: - ISO 8601 Parsing

    static func parseISO8601(_ string: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(string) {
            return date
        }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string)
    }

    // MARK: - Interval Reverse Lookup

    static let abbreviationToRawValue: [String: Int] = {
        var map: [String: Int] = [:]
        for interval in Interval.allCases {
            map[interval.abbreviation] = interval.rawValue
        }
        return map
    }()

    // MARK: - Line Splitting (Handles Quoted Newlines)

    static func splitIntoLines(_ content: String) -> [String] {
        var lines: [String] = []
        var current = ""
        var inQuotes = false
        var previousWasCR = false

        for scalar in content.unicodeScalars {
            if previousWasCR && scalar == "\n" && !inQuotes {
                previousWasCR = false
                continue
            }
            previousWasCR = false

            if scalar == "\"" {
                inQuotes.toggle()
                current.unicodeScalars.append(scalar)
            } else if scalar == "\r" && !inQuotes {
                lines.append(current)
                current = ""
                previousWasCR = true
            } else if scalar == "\n" && !inQuotes {
                lines.append(current)
                current = ""
            } else {
                current.unicodeScalars.append(scalar)
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        return lines
    }

    // MARK: - Export Formatting Utilities

    static func formatTimestamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    static func formatNoteName(_ midiNote: Int) -> String {
        MIDINote(midiNote).name
    }

    static func formatInterval(_ rawValue: Int) -> String {
        Interval(rawValue: rawValue)?.abbreviation ?? ""
    }

    static func formatDouble(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let formatted = String(value)
        if formatted.contains(".") {
            return formatted
        }
        return formatted + ".0"
    }

    static func formatOptionalDouble(_ value: Double?) -> String {
        guard let value else { return "" }
        return formatDouble(value)
    }

    // MARK: - RFC 4180 Escaping

    static func escapeField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

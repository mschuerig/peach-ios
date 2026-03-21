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
}

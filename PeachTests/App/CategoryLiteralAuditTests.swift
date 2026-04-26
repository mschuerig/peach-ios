import Testing
import Foundation
@testable import Peach

/// Source-level audit: aggregating screens and the post-refactor help content
/// must not branch on training-category literals or `switch discipline.category`.
/// Per Story 77.1 AC 5, every category-specific UI fragment moved into
/// per-discipline contributions; these screens are pure aggregators of the
/// registered set.
@Suite("Category-literal audit")
struct CategoryLiteralAuditTests {

    /// Regex patterns that match any direct branch on a ``TrainingCategory``
    /// literal. A bare `case .X` pattern is intentionally not audited:
    /// aggregating screens may switch over screen-local enums whose cases
    /// share names with ``TrainingCategory``; the `switch <expr>.category`
    /// pattern catches the head of any actual category switch.
    private static let forbiddenPatterns: [(label: String, pattern: String)] = [
        (".contains(.rhythm/.pitch/.intervals)", #"\.contains\(\s*\.(rhythm|pitch|intervals)\s*\)"#),
        (".category == .rhythm/.pitch/.intervals", #"\.category\s*==\s*\.(rhythm|pitch|intervals)\b"#),
        ("switch <expr>.category", #"\bswitch\s+[\w.]+\.category\b"#),
        ("if case .rhythm/.pitch/.intervals", #"\bif\s+case\s+\.(rhythm|pitch|intervals)\b"#),
    ]

    @Test("aggregating screens contain no category-literal gates", arguments: [
        "Peach/Settings/SettingsScreen.swift",
        "Peach/Profile/ProfileScreen.swift",
        "Peach/App/HelpContent.swift",
    ])
    func auditedFileContainsNoForbiddenLiteral(_ relativePath: String) throws {
        let url = try Self.projectFileURL(relativePath)
        let source = try String(contentsOf: url, encoding: .utf8)
        for (label, pattern) in Self.forbiddenPatterns {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(source.startIndex..., in: source)
            let match = regex.firstMatch(in: source, range: range)
            #expect(
                match == nil,
                "\(relativePath) contains forbidden category-literal pattern '\(label)'"
            )
        }
    }

    /// Resolves a project-relative path against the project root, derived from
    /// this test file's location at compile time. Skips the test (returns a
    /// failing precondition) if the project root cannot be located.
    private static func projectFileURL(_ relativePath: String) throws -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        // .../peach-ios/PeachTests/App/CategoryLiteralAuditTests.swift
        // → walk up two levels to PeachTests, then once more to peach-ios.
        let projectRoot = testFileURL
            .deletingLastPathComponent()  // App/
            .deletingLastPathComponent()  // PeachTests/
            .deletingLastPathComponent()  // peach-ios/
        return projectRoot.appendingPathComponent(relativePath)
    }
}

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

    private static let forbiddenSubstrings: [String] = [
        ".contains(.rhythm)",
        ".contains(.pitch)",
        ".contains(.intervals)",
        "switch discipline.category",
        "case .rhythm:",
        "case .pitch:",
        "case .intervals:",
    ]

    @Test("aggregating screens contain no category-literal gates", arguments: [
        "Peach/Settings/SettingsScreen.swift",
        "Peach/Profile/ProfileScreen.swift",
        "Peach/App/HelpContent.swift",
    ])
    func auditedFileContainsNoForbiddenLiteral(_ relativePath: String) throws {
        let url = try Self.projectFileURL(relativePath)
        let source = try String(contentsOf: url, encoding: .utf8)
        for forbidden in Self.forbiddenSubstrings {
            #expect(
                !source.contains(forbidden),
                "\(relativePath) contains forbidden category-literal '\(forbidden)'"
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

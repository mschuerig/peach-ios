import Foundation

// Catalog of ``TimingOffsetDetectionPattern`` entries.
//
// ID convention (revised in Story 84.4 iteration 4; supersedes the opaque
// `pattern_NN` convention from Story 84.1):
//   `pattern_<category>_NN` — `pattern_` prefix, then the category's
//   ``TimingOffsetDetectionPatternCategory/idToken`` (the enum case name in
//   camelCase form), then a zero-padded two-digit sequence number within
//   that category. Example: `pattern_straight16ths_01`,
//   `pattern_triplets_04`. The category prefix makes IDs communicable in
//   discussion; the per-category sequence keeps numbers stable when a
//   pattern is removed (numbers within a category are never reused —
//   removed patterns retire their number; new patterns take the next
//   available number in that category). Past `_99`, new entries within a
//   category widen to three digits; existing two-digit IDs are preserved.
//
// Retired ids:
//   (none yet — Epic 84 retires nothing)

/// Read-only registry of every ``TimingOffsetDetectionPattern`` available to
/// Timing Offset Detection. A namespace, not a singleton: the catalog has no
/// runtime mutation, no bootstrap step, and no override flow, so an `enum`
/// with static state is the simplest thing that works.
enum TimingOffsetDetectionPatternCatalog {

    /// Every registered pattern, in design-doc display order across categories.
    /// Categories appear in ``TimingOffsetDetectionPatternCategory/allCases``
    /// order: *Straight 16ths* → *Gapped 16ths* → *Triplets* → *Nested* →
    /// *Sextuplet*. Within a category, patterns appear in their per-category
    /// sequence number.
    ///
    /// **Build-flag gating.** Patterns in the *Nested* category
    /// (`pattern_nested_01`–`pattern_nested_05`) are wrapped in
    /// `#if PEACH_RESEARCH` so they are not part of `all` in non-research
    /// builds — the proportional-timeline bracket overlay needs further
    /// iteration before App Store users see them (see `PF-045`). The
    /// underlying `static let` definitions on ``TimingOffsetDetectionPattern``
    /// stay unconditional so renderer unit tests keep exercising the
    /// nested-figure code paths; only registration here is gated.
    ///
    /// **Adding or removing a category from the gate** is one in-place edit
    /// to this initializer: move that category's patterns in or out of the
    /// `#if PEACH_RESEARCH` block. No other code changes — categories are
    /// derived from the registered patterns via ``categories``. The closure
    /// form (instead of a literal with inline `#if`) is required because
    /// Swift does not allow `#if` inside array-literal expressions; the
    /// compile-time exclusion semantics are identical.
    static let all: [TimingOffsetDetectionPattern] = {
        var patterns: [TimingOffsetDetectionPattern] = [
            .pattern_straight16ths_01,

            .pattern_gapped16ths_01,
            .pattern_gapped16ths_02,
            .pattern_gapped16ths_03,
            .pattern_gapped16ths_04,

            .pattern_triplets_01,
            .pattern_triplets_02,
            .pattern_triplets_03,
            .pattern_triplets_04
        ]
        #if PEACH_RESEARCH
        patterns.append(contentsOf: [
            .pattern_nested_01,
            .pattern_nested_02,
            .pattern_nested_03,
            .pattern_nested_04,
            .pattern_nested_05
        ])
        #endif
        patterns.append(.pattern_sextuplet_01)
        return patterns
    }()

    /// Patterns in `category`, preserving their ``all`` display order. A
    /// category with no registered patterns in the current build returns `[]`.
    static func patterns(in category: TimingOffsetDetectionPatternCategory) -> [TimingOffsetDetectionPattern] {
        all.filter { $0.category == category }
    }

    /// Categories that have at least one registered pattern in the current
    /// build, in ``TimingOffsetDetectionPatternCategory/allCases`` display
    /// order. The picker iterates this; a gated-out category disappears
    /// naturally without a special case.
    static var categories: [TimingOffsetDetectionPatternCategory] {
        let registered = Set(all.map(\.category))
        return TimingOffsetDetectionPatternCategory.allCases.filter(registered.contains)
    }

    /// Id of the pattern used when no ``selectedPatternId`` is stored, and the
    /// fallback target when a stored id can't be resolved against ``all``.
    static let defaultPatternId: String = "pattern_straight16ths_01"

    /// The pattern referenced by ``defaultPatternId``. Traps if the default id
    /// is not registered — a catalog-invariant violation that must fail fast
    /// rather than silently produce a fallback Beat.
    static var defaultPattern: TimingOffsetDetectionPattern {
        guard let pattern = all.first(where: { $0.id == defaultPatternId }) else {
            preconditionFailure(
                "TimingOffsetDetectionPatternCatalog.defaultPatternId '\(defaultPatternId)' is not registered in `all`"
            )
        }
        return pattern
    }

    /// Looks up the registered pattern with the given id. Throws
    /// ``TimingOffsetDetectionPatternCatalogError/unknownPatternId(_:)`` on
    /// miss — never crashes. Callers decide whether to surface the error or
    /// fall back to ``defaultPattern``.
    static func pattern(withId id: String) throws(TimingOffsetDetectionPatternCatalogError) -> TimingOffsetDetectionPattern {
        guard let pattern = all.first(where: { $0.id == id }) else {
            throw .unknownPatternId(id)
        }
        return pattern
    }

    /// Looks up a pattern for an `@AppStorage`-stored id, silently falling back
    /// to ``defaultPattern`` on miss. The storage→domain logging policy lives at
    /// the port (`AppTimingOffsetDetectionUserSettings`); `@AppStorage` consumer
    /// sites in views use this helper to avoid duplicating the resolution.
    static func pattern(forStoredId id: String) -> TimingOffsetDetectionPattern {
        (try? pattern(withId: id)) ?? defaultPattern
    }
}

enum TimingOffsetDetectionPatternCatalogError: Error, Equatable {
    case unknownPatternId(String)
}

/// Picker category for ``TimingOffsetDetectionPattern`` entries — single-axis
/// classification by perceived host division + nesting, locked by
/// `tod-tuplet-renderer-design.md` § *Categorization*. Membership is
/// exclusive: every ``TimingOffsetDetectionPattern`` carries exactly one
/// ``TimingOffsetDetectionPattern/category``.
///
/// The bucket assignment is intentional: `pattern_gapped16ths_03`
/// (`* - * -`) lives in *Gapped 16ths* even though it audibly resembles two
/// straight 8ths — the design doc's rule is "host division 4 + contains
/// rests → Gapped 16ths" and adding a one-entry *8ths* category would
/// clutter the picker.
///
/// This enum is pure data — `idToken`, `localizedHeader`. Build-flag gating
/// lives in ``TimingOffsetDetectionPatternCatalog/all``'s registration, not
/// here; a category's membership in the active picker is determined by
/// whether any of its patterns are registered in the current build.
enum TimingOffsetDetectionPatternCategory: CaseIterable, Hashable {
    case straight16ths
    case gapped16ths
    case triplets
    case nested
    case sextuplet

    /// Stable token used as the category infix in pattern IDs
    /// (`pattern_<idToken>_NN`). Matches the enum case name verbatim in
    /// camelCase form so a pattern ID is round-trippable to its category by
    /// string match.
    var idToken: String {
        switch self {
        case .straight16ths: return "straight16ths"
        case .gapped16ths: return "gapped16ths"
        case .triplets: return "triplets"
        case .nested: return "nested"
        case .sextuplet: return "sextuplet"
        }
    }

    /// Picker section header in the user's locale. German wording locked by
    /// `tod-tuplet-renderer-design.md` § *Categorization*.
    var localizedHeader: String {
        switch self {
        case .straight16ths: return String(localized: "Straight 16ths")
        case .gapped16ths: return String(localized: "Gapped 16ths")
        case .triplets: return String(localized: "Triplets")
        case .nested: return String(localized: "Nested")
        case .sextuplet: return String(localized: "Sextuplet")
        }
    }
}

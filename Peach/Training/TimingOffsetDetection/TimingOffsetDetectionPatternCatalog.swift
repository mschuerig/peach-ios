import Foundation

/// Read-only registry of every ``TimingOffsetDetectionPattern`` available to
/// TOD. A namespace, not a singleton: the catalog has no runtime mutation, no
/// bootstrap step, and no override flow, so an `enum` with static state is the
/// simplest thing that works.
enum TimingOffsetDetectionPatternCatalog {

    /// Every registered pattern, in design-doc display order:
    /// ``TimingOffsetDetectionPattern/pattern1111``,
    /// ``TimingOffsetDetectionPattern/pattern1011``,
    /// ``TimingOffsetDetectionPattern/pattern1101``,
    /// ``TimingOffsetDetectionPattern/pattern1010``,
    /// ``TimingOffsetDetectionPattern/pattern1001``. The catalog spans two
    /// categories (locked by `docs/planning-artifacts/tod-initial-pattern-catalog.md`
    /// § *Categorization*): *Straight* — `pattern1111` (16ths) and `pattern1010`
    /// (8ths); *Gapped* — `pattern1011`, `pattern1101`, `pattern1001`. The picker
    /// presents them flat (no `Section`-chrome grouping) per the design doc.
    static let all: [TimingOffsetDetectionPattern] = [
        .pattern1111,
        .pattern1011,
        .pattern1101,
        .pattern1010,
        .pattern1001
    ]

    /// Id of the pattern used when no ``selectedPatternId`` is stored, and the
    /// fallback target when a stored id can't be resolved against ``all``.
    static let defaultPatternId: String = "pattern_1111"

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

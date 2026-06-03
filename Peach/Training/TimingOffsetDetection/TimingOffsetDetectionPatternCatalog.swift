import Foundation

/// Read-only registry of every ``TimingOffsetDetectionPattern`` available to
/// TOD. A namespace, not a singleton: the catalog has no runtime mutation, no
/// bootstrap step, and no override flow, so an `enum` with static state is the
/// simplest thing that works.
enum TimingOffsetDetectionPatternCatalog {

    /// Every registered pattern, in display order.
    ///
    /// 82.5 registers only ``TimingOffsetDetectionPattern/pattern1111``;
    /// 82.7 adds the four remaining catalog entries from
    /// `docs/planning-artifacts/tod-initial-pattern-catalog.md` § *Catalog*.
    static let all: [TimingOffsetDetectionPattern] = [.pattern1111]

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

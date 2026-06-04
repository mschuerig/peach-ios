import Foundation

// Catalog of ``TimingOffsetDetectionPattern`` entries.
//
// ID convention (locked in `tod-tuplet-renderer-design.md`, Story 84.1):
//   `pattern_NN` — sequential, zero-padded two-digit. Numbers are assigned
//   at first registration and never change; reordering this file does not
//   renumber entries. Removed entries' numbers are retired in the registry
//   below and never reused. New entries take the next available number.
//   Past `pattern_99`, new entries widen to three digits (`pattern_100`+);
//   existing two-digit ids are preserved.
//
// Retired ids:
//   (none yet — Epic 84 retires nothing)

/// Read-only registry of every ``TimingOffsetDetectionPattern`` available to
/// Timing Offset Detection. A namespace, not a singleton: the catalog has no
/// runtime mutation, no bootstrap step, and no override flow, so an `enum`
/// with static state is the simplest thing that works.
enum TimingOffsetDetectionPatternCatalog {

    /// Every registered pattern, in design-doc display order:
    /// ``TimingOffsetDetectionPattern/pattern01``,
    /// ``TimingOffsetDetectionPattern/pattern02``,
    /// ``TimingOffsetDetectionPattern/pattern03``,
    /// ``TimingOffsetDetectionPattern/pattern04``,
    /// ``TimingOffsetDetectionPattern/pattern05``. The catalog spans two
    /// categories (locked by `docs/planning-artifacts/tod-initial-pattern-catalog.md`
    /// § *Categorization*): *Straight* — `pattern_01` (16ths) and `pattern_04`
    /// (8ths); *Gapped* — `pattern_02`, `pattern_03`, `pattern_05`. The picker
    /// presents them flat (no `Section`-chrome grouping) per the design doc.
    static let all: [TimingOffsetDetectionPattern] = [
        .pattern01,
        .pattern02,
        .pattern03,
        .pattern04,
        .pattern05
    ]

    /// Id of the pattern used when no ``selectedPatternId`` is stored, and the
    /// fallback target when a stored id can't be resolved against ``all``.
    static let defaultPatternId: String = "pattern_01"

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

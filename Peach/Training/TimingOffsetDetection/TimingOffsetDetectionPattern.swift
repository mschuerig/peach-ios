import Foundation

/// Path from the top-level beat to a `.note` leaf — the index sequence taken at
/// each depth to reach the leaf. Top-level leaves have single-element paths;
/// leaves inside a `.nested(Beat)` child have multi-element paths.
typealias GridPath = [Int]

/// A TOD pattern wrapping the `[Subdivision]` shape of a single-beat figure with
/// the metadata needed to address it from the user-facing layer.
///
/// User-facing positions are *audible* (1-based, compressing rests); engine
/// addressing is by ``GridPath`` (a path-from-root through the `Beat` tree).
/// The translation runs through the precomputed ``audibleToGrid`` table —
/// never via raw arithmetic on the audible index — so a pattern with rests or
/// nested figures cannot land the offset on a `.rest` subdivision (which
/// ``Beat/events(...)`` would drop) or skip past a nested child.
///
/// ``pickable`` excludes audible position 1 for every pattern: the first
/// audible note is the metric anchor of the figure and is the perceptual
/// reference for the user's direction judgment. See
/// `docs/planning-artifacts/tod-initial-pattern-catalog.md` § *Pickable-position rule*.
struct TimingOffsetDetectionPattern: Sendable {
    let id: String
    let subdivisions: [Subdivision]
    let defaultOffsetNotePosition: OffsetNotePosition

    /// Audible-1-based → ``GridPath`` map. Built at init by a depth-first walk
    /// of ``subdivisions``: each `.note` contributes its path; each
    /// `.nested(Beat)` extends the path by the child's index and recurses;
    /// `.rest` is skipped. Top-level audibles have single-element paths
    /// (`[0]`, `[2]`); nested audibles have multi-element paths (`[1, 0]`).
    let audibleToGrid: [GridPath]

    /// Audible positions the user may pick as the Offset Note. Always excludes
    /// position 1 (the metric anchor) per the perceptual analysis in the
    /// catalog design doc.
    let pickable: Set<Int>

    /// Audible positions whose VoiceOver label carries the "dotted" descriptor —
    /// a perceptual property of mixed-duration triplet derivatives where the
    /// audible spans a longer fraction of the beat than its grid-cell siblings
    /// (see `tod-tuplet-renderer-design.md` § *Per-cell accessibility labels*).
    /// Empty for the Epic-82 flat patterns; populated by Epic 84.4 for the
    /// mixed-duration `* *. .` entry.
    let dottedAudiblePositions: Set<Int>

    var audibleCount: Int { audibleToGrid.count }

    init(
        id: String,
        subdivisions: [Subdivision],
        defaultOffsetNotePosition: OffsetNotePosition,
        dottedAudiblePositions: Set<Int> = []
    ) {
        let audibleToGrid = Self.collectAudiblePaths(in: subdivisions, pathPrefix: [])
        let pickable: Set<Int> = audibleToGrid.count >= 2 ? Set(2...audibleToGrid.count) : []

        self.id = id
        self.subdivisions = subdivisions
        self.defaultOffsetNotePosition = defaultOffsetNotePosition
        self.audibleToGrid = audibleToGrid
        self.pickable = pickable
        self.dottedAudiblePositions = dottedAudiblePositions

        // Catalog-wide invariant: the default must itself be a pickable position.
        // Caught at construction time so a misregistered pattern in the catalog
        // surfaces before any session reads from it.
        precondition(
            pickable.contains(defaultOffsetNotePosition.rawValue),
            "TimingOffsetDetectionPattern '\(id)' default \(defaultOffsetNotePosition.rawValue) is not pickable"
        )
    }

    private static func collectAudiblePaths(
        in subdivisions: [Subdivision],
        pathPrefix: GridPath
    ) -> [GridPath] {
        var paths: [GridPath] = []
        for (index, subdivision) in subdivisions.enumerated() {
            switch subdivision {
            case .rest:
                continue
            case .note:
                paths.append(pathPrefix + [index])
            case .nested(let child):
                paths.append(contentsOf: collectAudiblePaths(
                    in: child.subdivisions,
                    pathPrefix: pathPrefix + [index]
                ))
            }
        }
        return paths
    }

    /// Builds the `Beat` for one TOD trial. The offset is applied to exactly the
    /// `.note` leaf addressed by ``audibleToGrid``\[`offsetNotePosition.zeroBasedIndex`\];
    /// every other `.note` keeps `.zero` offset; `.rest` subdivisions are
    /// preserved; `.nested(Beat)` subdivisions are reconstructed recursively so
    /// the offset can land on a nested-child leaf.
    ///
    /// - Precondition: `pickable.contains(offsetNotePosition.rawValue)`. The
    ///   caller must clamp first via ``clampedOffsetNotePosition(_:)`` — passing
    ///   the metric anchor (audible position 1) or any out-of-range value is a
    ///   programmer error.
    func beat(offsetNotePosition: OffsetNotePosition, offsetAmount: Duration) -> Beat {
        precondition(
            pickable.contains(offsetNotePosition.rawValue),
            "TimingOffsetDetectionPattern '\(id)' cannot place an offset on audible position \(offsetNotePosition.rawValue)"
        )

        let offsetPath = audibleToGrid[offsetNotePosition.zeroBasedIndex]
        return Beat(subdivisions: Self.rebuild(
            subdivisions: subdivisions,
            applyOffsetAtPath: offsetPath,
            offsetAmount: offsetAmount
        ))
    }

    private static func rebuild(
        subdivisions: [Subdivision],
        applyOffsetAtPath path: GridPath,
        offsetAmount: Duration
    ) -> [Subdivision] {
        guard let firstIndex = path.first else { return subdivisions }
        let remainingPath = Array(path.dropFirst())

        return subdivisions.enumerated().map { index, subdivision in
            switch subdivision {
            case .rest:
                return subdivision
            case .note(let velocity, _):
                let isTargetLeaf = (index == firstIndex) && remainingPath.isEmpty
                return .note(velocity: velocity, offset: isTargetLeaf ? offsetAmount : .zero)
            case .nested(let child):
                guard index == firstIndex, !remainingPath.isEmpty else {
                    return subdivision
                }
                let rebuiltChild = rebuild(
                    subdivisions: child.subdivisions,
                    applyOffsetAtPath: remainingPath,
                    offsetAmount: offsetAmount
                )
                return .nested(Beat(subdivisions: rebuiltChild))
            }
        }
    }

    /// Maps a stored 1-based `Int` to a valid ``OffsetNotePosition`` for this
    /// pattern: returns the strict ``OffsetNotePosition`` if the raw value is in
    /// ``pickable``, otherwise the pattern's ``defaultOffsetNotePosition``. The
    /// sole read path from `@AppStorage` to a usable position — direct
    /// ``OffsetNotePosition`` construction at consumer sites bypasses both the
    /// metric-anchor exclusion and the range check.
    func clampedOffsetNotePosition(_ rawValue: Int) -> OffsetNotePosition {
        guard OffsetNotePosition.validRange.contains(rawValue),
              pickable.contains(rawValue) else {
            return defaultOffsetNotePosition
        }
        return OffsetNotePosition(rawValue)
    }
}

// MARK: - Equatable / Hashable

extension TimingOffsetDetectionPattern: Hashable {
    /// Identity is the stable id: catalog entries are uniquely keyed by it, and
    /// `subdivisions` (`[Subdivision]`) isn't `Hashable`. Defining equality on
    /// id keeps lookups and set membership cheap without forcing the engine
    /// types to widen their conformance.
    static func == (lhs: TimingOffsetDetectionPattern, rhs: TimingOffsetDetectionPattern) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Static catalog entries

extension TimingOffsetDetectionPattern {
    /// `* * * *` — four equally-spaced 16ths, accent on grid position 1, every
    /// audible position non-anchor pickable. The migration target for 82.1
    /// users: with stored `offsetNotePosition ∈ {2, 3, 4}`, the emitted `Beat`
    /// is bit-identical to the pre-82.5 hand-rolled construction.
    ///
    /// Default 3: audible 3 = grid 3 = on the half-beat. The perceptually
    /// strongest non-anchor position in a 4-subdivision figure.
    static let pattern01 = TimingOffsetDetectionPattern(
        id: "pattern_01",
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(3)
    )

    /// `* - * *` — anchor, rest, two audible. `audibleToGrid = [[0], [2], [3]]`;
    /// `pickable = {2, 3}`.
    ///
    /// Default 2: audible 2 = grid 2 = on the half-beat. Closest analogue to
    /// the `pattern_01` default — both sit on the metric midpoint of the
    /// figure.
    static let pattern02 = TimingOffsetDetectionPattern(
        id: "pattern_02",
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `* * - *` — anchor, audible, rest, audible. `audibleToGrid = [[0], [1], [3]]`;
    /// `pickable = {2, 3}`.
    ///
    /// Default 2: the on-the-half-beat audible note is a rest in this pattern.
    /// Audible 2 (grid 2, the early subdivision) and audible 3 (grid 4, the
    /// tail) are both equidistant from the rest at grid 3 — a tie. Audible 2
    /// is the starting pick; playtest evidence may revise it later. (Grid
    /// numbers here are 1-based, matching the design doc's table notation.)
    static let pattern03 = TimingOffsetDetectionPattern(
        id: "pattern_03",
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `* - * -` — anchor, rest, audible, rest. `audibleToGrid = [[0], [2]]`;
    /// `pickable = {2}` (single-pickable).
    ///
    /// Default 2: forced — the only pickable audible position. Encoded as a
    /// 4-subdivision `Beat` (not 2) so the equal-cell renderer shows it
    /// alongside the other catalog entries with consistent cell counts; the
    /// audible perception (an "8ths feel") is unchanged.
    static let pattern04 = TimingOffsetDetectionPattern(
        id: "pattern_04",
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .rest
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `* - - *` — anchor, two rests, audible tail. `audibleToGrid = [[0], [3]]`;
    /// `pickable = {2}` (single-pickable).
    ///
    /// Default 2: forced — the only pickable audible position. Probes
    /// "anchor + tail" timing perception: judging the timing of a note
    /// separated from its preceding reference by two rests (common in march,
    /// dotted-eighth-plus-16th figures, folk strumming).
    static let pattern05 = TimingOffsetDetectionPattern(
        id: "pattern_05",
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .rest,
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )
}

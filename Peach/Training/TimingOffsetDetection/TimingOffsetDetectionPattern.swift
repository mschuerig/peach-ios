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
    let category: TimingOffsetDetectionPatternCategory
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
        category: TimingOffsetDetectionPatternCategory,
        subdivisions: [Subdivision],
        defaultOffsetNotePosition: OffsetNotePosition,
        dottedAudiblePositions: Set<Int> = []
    ) {
        // ID schema invariant: `pattern_<category-idToken>_NN`. Validated at
        // construction so a misregistered pattern surfaces before it reaches
        // `@AppStorage` or the picker.
        let expectedPrefix = "pattern_\(category.idToken)_"
        precondition(
            id.hasPrefix(expectedPrefix),
            "TimingOffsetDetectionPattern '\(id)' does not match the '\(expectedPrefix)NN' ID schema for category \(category)"
        )

        let audibleToGrid = Self.collectAudiblePaths(in: subdivisions, pathPrefix: [])
        let pickable: Set<Int> = audibleToGrid.count >= 2 ? Set(2...audibleToGrid.count) : []

        // Catalog-wide invariant: every dotted descriptor must address a
        // non-anchor audible position that actually exists. Caught at
        // construction so a misregistered pattern surfaces before its
        // descriptor is silently dropped at render time.
        precondition(
            dottedAudiblePositions.allSatisfy { (2...audibleToGrid.count).contains($0) },
            "TimingOffsetDetectionPattern '\(id)' dottedAudiblePositions \(dottedAudiblePositions.sorted()) contains out-of-range or anchor positions (must be in 2...\(audibleToGrid.count))"
        )

        self.id = id
        self.category = category
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
    /// audible position non-anchor pickable.
    ///
    /// Default 3: audible 3 = grid 3 = on the half-beat. The perceptually
    /// strongest non-anchor position in a 4-subdivision figure.
    static let pattern_straight16ths_01 = TimingOffsetDetectionPattern(
        id: "pattern_straight16ths_01",
        category: .straight16ths,
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
    /// Default 2: audible 2 = grid 2 = on the half-beat.
    static let pattern_gapped16ths_01 = TimingOffsetDetectionPattern(
        id: "pattern_gapped16ths_01",
        category: .gapped16ths,
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
    /// Default 2: audible 2 (grid 2) and audible 3 (grid 4) are both
    /// equidistant from the rest at grid 3 — a tie. Audible 2 is the starting
    /// pick; playtest evidence may revise.
    static let pattern_gapped16ths_02 = TimingOffsetDetectionPattern(
        id: "pattern_gapped16ths_02",
        category: .gapped16ths,
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
    /// Default 2: forced — the only pickable audible position. Audibly an
    /// "8ths feel" on a 16ths grid.
    static let pattern_gapped16ths_03 = TimingOffsetDetectionPattern(
        id: "pattern_gapped16ths_03",
        category: .gapped16ths,
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
    /// Default 2: forced. Probes "anchor + tail" timing perception (common in
    /// march, dotted-eighth-plus-16th figures, folk strumming).
    static let pattern_gapped16ths_04 = TimingOffsetDetectionPattern(
        id: "pattern_gapped16ths_04",
        category: .gapped16ths,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .rest,
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `* * *` — three equal 8th-triplet notes. `audibleToGrid = [[0], [1], [2]]`;
    /// `pickable = {2, 3}`.
    ///
    /// Default 2: middle of the triplet — the clearest "between-anchors" probe.
    static let pattern_triplets_01 = TimingOffsetDetectionPattern(
        id: "pattern_triplets_01",
        category: .triplets,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `* * -` — 8th-triplet with trailing rest. `audibleToGrid = [[0], [1]]`;
    /// `pickable = {2}` (single-pickable). Common in jazz comping and bossa
    /// nova clave fragments. Default 2 is forced.
    static let pattern_triplets_02 = TimingOffsetDetectionPattern(
        id: "pattern_triplets_02",
        category: .triplets,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .rest
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `* - *` — 8th-triplet "long-short-long". `audibleToGrid = [[0], [2]]`;
    /// `pickable = {2}` (single-pickable). Common in waltz syncopation and
    /// Celtic-style triplet figures. Default 2 is forced.
    static let pattern_triplets_03 = TimingOffsetDetectionPattern(
        id: "pattern_triplets_03",
        category: .triplets,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `* *. .` — mixed-duration triplet, sextuplet-grid representation with
    /// multi-cell holds. `audibleToGrid = [[0], [2], [5]]`; `pickable = {2, 3}`;
    /// audible 2 carries the perceptual "dotted" descriptor (its grid cell
    /// spans 1-based grid positions 3–5, i.e. half the beat).
    ///
    /// Default 2: the dotted (long) cell — perceptually most marked.
    static let pattern_triplets_04 = TimingOffsetDetectionPattern(
        id: "pattern_triplets_04",
        category: .triplets,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .rest,
            .rest,
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2),
        dottedAudiblePositions: [2]
    )

    /// `* *-*-*` — 8th + nested 16th-triplet at host position 2.
    /// `audibleToGrid = [[0], [1, 0], [1, 1], [1, 2]]`; `pickable = {2, 3, 4}`.
    /// Common in jazz fills, prog rock, and Indian classical tihai-adjacent
    /// figures.
    ///
    /// Default 3: middle of the nested 16th-triplet — cross-rhythm probe at
    /// the densest point of the figure.
    static let pattern_nested_01 = TimingOffsetDetectionPattern(
        id: "pattern_nested_01",
        category: .nested,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .nested(Beat(subdivisions: [
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ]))
        ],
        defaultOffsetNotePosition: OffsetNotePosition(3)
    )

    /// `*-*-* *` — nested 16th-triplet at host position 1 (leading) + 8th.
    /// `audibleToGrid = [[0, 0], [0, 1], [0, 2], [1]]`; `pickable = {2, 3, 4}`.
    /// Mirror of ``pattern_nested_01``; pair coverage between trailing density
    /// and leading density.
    ///
    /// Default 3: middle of the nested 16th-triplet (mirror reasoning).
    static let pattern_nested_02 = TimingOffsetDetectionPattern(
        id: "pattern_nested_02",
        category: .nested,
        subdivisions: [
            .nested(Beat(subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ])),
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(3)
    )

    /// `* * .-.` — 8th-triplet with trailing duplet (cross-rhythm into next
    /// beat). `audibleToGrid = [[0], [1], [2, 0], [2, 1]]`; `pickable = {2, 3, 4}`.
    /// Common in West African and Cuban contexts.
    ///
    /// Default 4: second cell of the trailing duplet — the cross-rhythm
    /// landing into the next beat.
    static let pattern_nested_03 = TimingOffsetDetectionPattern(
        id: "pattern_nested_03",
        category: .nested,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .nested(Beat(subdivisions: [
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ]))
        ],
        defaultOffsetNotePosition: OffsetNotePosition(4)
    )

    /// `* .-. *` — 8th-triplet with middle duplet (symmetric center case).
    /// `audibleToGrid = [[0], [1, 0], [1, 1], [2]]`; `pickable = {2, 3, 4}`.
    /// Least common of the three duplet-in-triplet entries in real repertoire
    /// but valuable as the symmetric center case.
    ///
    /// Default 3: second cell of the middle duplet — middle cross-rhythm.
    static let pattern_nested_04 = TimingOffsetDetectionPattern(
        id: "pattern_nested_04",
        category: .nested,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .nested(Beat(subdivisions: [
                .note(velocity: RhythmVelocity.normal, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ])),
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(3)
    )

    /// `.-. * *` — leading duplet (downbeat cross-rhythm) + 8th-triplet tail.
    /// `audibleToGrid = [[0, 0], [0, 1], [1], [2]]`; `pickable = {2, 3, 4}`.
    /// Very common — most Latin syncopation begins this way.
    ///
    /// Default 2: second cell of the leading duplet — the "cross-rhythm
    /// settle" before the host triplet resumes.
    static let pattern_nested_05 = TimingOffsetDetectionPattern(
        id: "pattern_nested_05",
        category: .nested,
        subdivisions: [
            .nested(Beat(subdivisions: [
                .note(velocity: RhythmVelocity.accent, offset: .zero),
                .note(velocity: RhythmVelocity.normal, offset: .zero)
            ])),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(2)
    )

    /// `. . . . . .` — flat sextuplet. `audibleToGrid = [[0], [1], [2], [3], [4], [5]]`;
    /// `pickable = {2, 3, 4, 5, 6}`. Covers fast-passagework timing perception.
    ///
    /// Default 4: perceptual midpoint (3/6 = half-beat) — the strongest
    /// secondary pulse in a flat sextuplet.
    static let pattern_sextuplet_01 = TimingOffsetDetectionPattern(
        id: "pattern_sextuplet_01",
        category: .sextuplet,
        subdivisions: [
            .note(velocity: RhythmVelocity.accent, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero),
            .note(velocity: RhythmVelocity.normal, offset: .zero)
        ],
        defaultOffsetNotePosition: OffsetNotePosition(4)
    )
}

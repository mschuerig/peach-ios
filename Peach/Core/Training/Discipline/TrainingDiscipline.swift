import Foundation

/// Defines the contract for a training discipline: display metadata, statistics configuration,
/// payload type, data integration points (profile feeding, CSV formatting, duplicate detection),
/// and CSV column ownership (export/import).
///
/// Each discipline is a conforming struct defined in its respective feature directory.
/// The ``TrainingDisciplineRegistry`` is the single place that knows which disciplines are active.
///
/// View-producing requirements live on the App-layer refinement
/// ``TrainingDisciplineUI``; Core stays Foundation-only so Core/Data services
/// (`TrainingDataExporter`, `CSVImportParser`, `TrainingDataStore`) can consume
/// the registry without pulling SwiftUI into the data layer.
///
/// ## Existential boundary and the typed `Payload`
///
/// The registry stores `[any TrainingDiscipline]`; cross-cutting iteration
/// (export, import, profile rebuild) needs a heterogeneous list. Inside each
/// conforming type, however, the discipline knows its concrete payload type,
/// and forcing it back through `any TrainingDisciplinePayload` would require
/// `as?` casts that cannot fail in practice.
///
/// `Payload` makes the per-discipline payload type concrete: methods that
/// return or accept payloads use `Payload`, the four conformers stop
/// downcasting, and the cross-cutting registry-level callers go through
/// type-erasing protocol extensions (``csvRows(from:)``,
/// ``parsedRecordEnvelopes(from:)``, ``parseCSVRowErased(fields:columnIndex:rowNumber:)``)
/// whose visible signatures expose only `any TrainingDisciplinePayload` or
/// concrete value types — so they remain callable on the existential.
///
/// The four `Payload`-typed primitives (``csvKeyValuePairs(for:)``,
/// ``parseCSVRow(fields:columnIndex:rowNumber:)``,
/// ``fetchExportRecords(from:)``, ``parsedRecords(from:)``) cannot be
/// invoked on `any TrainingDiscipline` directly; registry-level callers
/// must go through the existential-callable helpers above.
protocol TrainingDiscipline: Sendable {
    /// The concrete payload type this discipline owns. Conformers typically
    /// let this be inferred from the return types of payload-shaped methods.
    associatedtype Payload: TrainingDisciplinePayload

    /// Stable identifier for this discipline.
    var id: TrainingDisciplineID { get }

    /// Display partition for grouping in lists and menus. Each discipline
    /// belongs to exactly one category.
    var category: TrainingCategory { get }

    /// Display and statistics configuration (name, unit label, baseline, EWMA parameters).
    var config: TrainingDisciplineConfig { get }

    /// The statistics keys this discipline contributes to the profile.
    /// Pitch disciplines return a single key; rhythm disciplines return tempo × direction permutations.
    var statisticsKeys: [StatisticsKey] { get }

    /// Help sections shown when the user opens the help sheet for this discipline.
    var helpSections: [HelpSection] { get }

    /// Routing target for navigating to this discipline's training screen.
    var navigationDestination: NavigationDestination { get }

    /// Feeds stored payloads into a profile builder for initial profile construction.
    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws

    // MARK: - CSV Column Ownership

    /// The training type string used in CSV export/import (e.g., "pitchDiscrimination").
    /// This is a stable wire-format identifier shared with other apps (e.g., peach-web)
    /// and must not change when internal type names are renamed.
    var csvTrainingType: String { get }

    /// Column names specific to this discipline (excluding common columns: trainingType, timestamp).
    var csvColumns: [String] { get }

    /// CSV format history: the format versions this discipline appeared in,
    /// the trainingType identifier and columns at each version, and any
    /// value transforms attached to a version's introduction.
    /// The migration runner derives v → v+1 operations from these snapshots.
    var csvHistory: CSVHistory { get }

    /// Produces key-value pairs from a payload for CSV export.
    /// Keys are column names from ``csvColumns``.
    func csvKeyValuePairs(for payload: Payload) -> [(String, String)]

    /// Parses a CSV row into a `(timestamp, payload)` pair using named column lookup.
    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: Payload), CSVImportError>

    /// Fetches this discipline's payloads for export, sorted by timestamp.
    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: Payload)]

    /// Returns this discipline's parsed payloads from a CSV import result.
    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: Payload)]

    /// Merges imported payloads, skipping duplicates that already exist in the store.
    /// Reads existing payloads from `store` for duplicate detection; encodes new
    /// payloads into envelopes and inserts them through `scope`.
    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int)
}

// MARK: - Existential-callable helpers
//
// Cross-cutting registry callers iterate `[any TrainingDiscipline]`, where the
// associated `Payload` is hidden. The methods below are the boundary that
// erases per-discipline payload types into shapes the registry can consume:
// each combines one or more `Payload`-typed primitive operations and exposes
// only existential or concrete return types, so it remains callable on the
// existential.

extension TrainingDiscipline {
    /// Type-erased view of ``parseCSVRow(fields:columnIndex:rowNumber:)`` for
    /// the registry-driven CSV parser, which dispatches by `trainingType`
    /// and stores results in a heterogeneous map keyed by that string.
    func parseCSVRowErased(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: any TrainingDisciplinePayload), CSVImportError> {
        parseCSVRow(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber)
            .map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
    }

    /// Returns one CSV (timestamp, key-value-pairs) tuple per exportable record.
    /// Combines ``fetchExportRecords(from:)`` and ``csvKeyValuePairs(for:)``
    /// so the exporter doesn't traffic in associated-type-shaped pairs.
    func csvRows(from store: TrainingDataStore) throws -> [(timestamp: Date, pairs: [(String, String)])] {
        try fetchExportRecords(from: store).map { ($0.timestamp, csvKeyValuePairs(for: $0.payload)) }
    }

    /// Encodes parsed CSV payloads into envelopes for the replace-mode importer.
    /// Pre-sizes the envelope array via `reserveCapacity` so the loop avoids
    /// the second peak that an extra `.map` would allocate.
    func parsedRecordEnvelopes(
        from parseResult: CSVImportParser.ImportResult
    ) throws -> [TrainingRecord] {
        let parsed = parsedRecords(from: parseResult)
        var envelopes: [TrainingRecord] = []
        envelopes.reserveCapacity(parsed.count)
        for entry in parsed {
            envelopes.append(try JSONEnvelope.encode(entry.payload, timestamp: entry.timestamp))
        }
        return envelopes
    }
}

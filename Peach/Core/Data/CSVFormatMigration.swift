import Foundation

/// History-derived CSV row migration.
///
/// The chain has no per-version step types: every operation it produces is
/// derived from the ``CSVHistory`` snapshots in ``CSVHistoryRegistry/shared``.
/// For each (v → v+1) step, the chain inspects every history's entry at
/// `v+1` and assembles the operations that took effect at that step:
///
/// - **trainingType rename** — when an entry at `v+1` differs from the
///   history's previous entry, rows whose `trainingType` matches the previous
///   identifier are rewritten to the v+1 identifier.
/// - **previous-identifier rename** — when a history first appears at `v+1`
///   and declares ``CSVHistoryEntry/previousTrainingType``, rows under the
///   retired identifier are rewritten to the new one.
/// - **value transforms** — any ``CSVValueTransform`` listed in the v+1 entry
///   is applied to all rows in the step.
///
/// Column-level adds and drops are not materialized into the row dictionaries
/// here: ``CSVImportParser`` reconstructs the row dictionary against the union
/// of registry-declared columns and any keys present in the migrated rows, so
/// missing column keys default to empty strings naturally.
enum CSVMigrationChain {

    /// Migrates `rows` from `sourceVersion` up to `targetVersion`. Returns
    /// `nil` for `sourceVersion < 1` or `sourceVersion > targetVersion`. A
    /// no-op step (`sourceVersion == targetVersion`) returns `rows` unchanged.
    static func migrate(from sourceVersion: Int, to targetVersion: Int, rows: [[String: String]]) -> [[String: String]]? {
        guard sourceVersion >= 1, sourceVersion <= targetVersion else { return nil }

        var currentRows = rows
        var v = sourceVersion
        while v < targetVersion {
            currentRows = applyStep(introducing: v + 1, to: currentRows)
            v += 1
        }
        return currentRows
    }

    /// Applies the operations introduced *at* `nextVersion` (i.e., the ones
    /// that took effect during the (`nextVersion - 1` → `nextVersion`) step).
    private static func applyStep(introducing nextVersion: Int, to rows: [[String: String]]) -> [[String: String]] {
        var trainingTypeRenames: [String: String] = [:]
        var globalTransforms: [CSVValueTransform] = []

        for history in CSVHistoryRegistry.shared.histories {
            guard let next = history.entry(at: nextVersion) else { continue }

            globalTransforms.append(contentsOf: next.valueTransformsFromPrevious)

            let renameSource: String?
            if let previousEntry = history.entries.last(where: { $0.version < nextVersion }) {
                renameSource = previousEntry.trainingType != next.trainingType ? previousEntry.trainingType : nil
            } else {
                renameSource = next.previousTrainingType
            }
            if let source = renameSource {
                precondition(
                    trainingTypeRenames[source] == nil,
                    "Conflicting trainingType rename at v\(nextVersion): \(source) is renamed by more than one history"
                )
                trainingTypeRenames[source] = next.trainingType
            }
        }

        // Two histories must not contribute a chain (A→B and B→C) within the
        // same step: applyStep applies a row's rename once, so the chain would
        // truncate silently. Detect at construction.
        let renameTargets = Set(trainingTypeRenames.values)
        let renameSources = Set(trainingTypeRenames.keys)
        let chained = renameTargets.intersection(renameSources)
        precondition(
            chained.isEmpty,
            "Transitive trainingType rename at v\(nextVersion): \(chained.sorted()) appears as both source and target"
        )

        // Transforms run sequentially in registry order; overlapping from/to
        // keys would make the result depend on declaration order. Disallow.
        var transformKeys: Set<String> = []
        for transform in globalTransforms {
            switch transform {
            case let .renameColumnWithFallback(from, to):
                let touched: Set<String> = [from, to]
                precondition(
                    transformKeys.isDisjoint(with: touched),
                    "Overlapping CSVValueTransform keys at v\(nextVersion): \(touched.intersection(transformKeys).sorted())"
                )
                transformKeys.formUnion(touched)
            }
        }

        return rows.map { row in
            var migrated = row
            if let trainingType = migrated["trainingType"],
               let renamed = trainingTypeRenames[trainingType] {
                migrated["trainingType"] = renamed
            }
            for transform in globalTransforms {
                migrated = transform.apply(to: migrated)
            }
            return migrated
        }
    }
}

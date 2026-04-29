import Testing
import SwiftData
import Foundation
@testable import Peach

/// Covers ``TrainingDataStore/TransactionScope/mergeImportPayloads(_:existing:keyFor:)``,
/// the shared encode-and-insert-if-new helper that powers each discipline's
/// `mergeImportRecords` body.
@Suite("TransactionScope mergeImportPayloads")
struct TransactionScopeMergeImportTests {

    // MARK: - Helpers

    private func makeStore() throws -> TrainingDataStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrainingRecord.self, configurations: config)
        return TrainingDataStore(modelContext: ModelContext(container))
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000 + minutesOffset * 60)
    }

    private func sampleDiscriminationPayload(
        targetNote: Int = 64,
        centOffset: Double = 25.0
    ) -> PitchDiscriminationPayload {
        PitchDiscriminationPayload(
            referenceNote: 60,
            targetNote: targetNote,
            centOffset: centOffset,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament"
        )
    }

    private func keyFor(timestamp: Date, payload: PitchDiscriminationPayload) -> PitchDuplicateKey {
        PitchDuplicateKey(timestamp: timestamp, payload: payload, trainingType: "pitchDiscrimination")
    }

    // MARK: - Tests

    @Test("imports every entry when the index is empty")
    func importsAllWhenSetIsEmpty() async throws {
        let store = try makeStore()
        let entries: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [
            (fixedDate(minutesOffset: 0), sampleDiscriminationPayload(targetNote: 64)),
            (fixedDate(minutesOffset: 1), sampleDiscriminationPayload(targetNote: 65)),
            (fixedDate(minutesOffset: 2), sampleDiscriminationPayload(targetNote: 66)),
        ]
        var existing = DuplicateKeyIndex<PitchDuplicateKey>()

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existing: &existing, keyFor: keyFor)
        }

        #expect(result.imported == 3)
        #expect(result.skipped == 0)
        #expect(existing.strictKeys.count == 3)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 3)
    }

    @Test("skips every entry whose key is already present")
    func skipsAllWhenAllAreDuplicates() async throws {
        let store = try makeStore()
        let entries: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [
            (fixedDate(minutesOffset: 0), sampleDiscriminationPayload(targetNote: 64)),
            (fixedDate(minutesOffset: 1), sampleDiscriminationPayload(targetNote: 65)),
        ]
        var existing = DuplicateKeyIndex<PitchDuplicateKey>(
            strictKeys: Set(entries.map { keyFor(timestamp: $0.timestamp, payload: $0.payload) })
        )

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existing: &existing, keyFor: keyFor)
        }

        #expect(result.imported == 0)
        #expect(result.skipped == 2)
        #expect(existing.strictKeys.count == 2)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 0)
    }

    @Test("skips entries whose timestamp matches a skipped existing envelope")
    func skipsEntriesMatchingSkippedTimestamp() async throws {
        let store = try makeStore()
        let collidingTimestamp = fixedDate(minutesOffset: 0)
        let entries: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [
            (collidingTimestamp, sampleDiscriminationPayload(targetNote: 64)),
            (fixedDate(minutesOffset: 1), sampleDiscriminationPayload(targetNote: 65)),
        ]
        // Existing index has no strict key for the colliding timestamp (the
        // existing envelope was undecodable), but does record it as skipped.
        var existing = DuplicateKeyIndex<PitchDuplicateKey>(
            skippedTimestamps: [collidingTimestamp]
        )

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existing: &existing, keyFor: keyFor)
        }

        #expect(result.imported == 1)
        #expect(result.skipped == 1)
        #expect(existing.strictKeys.count == 1)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 1)
    }

    @Test("imports only entries whose key is not yet known")
    func importsOnlyNovelEntries() async throws {
        let store = try makeStore()
        let known = (fixedDate(minutesOffset: 0), sampleDiscriminationPayload(targetNote: 64))
        let novel1 = (fixedDate(minutesOffset: 1), sampleDiscriminationPayload(targetNote: 65))
        let novel2 = (fixedDate(minutesOffset: 2), sampleDiscriminationPayload(targetNote: 66))
        let entries = [known, novel1, novel2]
        var existing = DuplicateKeyIndex<PitchDuplicateKey>(
            strictKeys: [keyFor(timestamp: known.0, payload: known.1)]
        )

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existing: &existing, keyFor: keyFor)
        }

        #expect(result.imported == 2)
        #expect(result.skipped == 1)
        #expect(existing.strictKeys.count == 3)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 2)
    }

    @Test("returns (0, 0) and leaves the index untouched for an empty batch")
    func emptyBatchReturnsZerosAndNoOps() async throws {
        let store = try makeStore()
        let entries: [(timestamp: Date, payload: PitchDiscriminationPayload)] = []
        var existing = DuplicateKeyIndex<PitchDuplicateKey>(
            strictKeys: [keyFor(timestamp: fixedDate(minutesOffset: 0), payload: sampleDiscriminationPayload(targetNote: 64))]
        )
        let snapshot = existing.strictKeys

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existing: &existing, keyFor: keyFor)
        }

        #expect(result.imported == 0)
        #expect(result.skipped == 0)
        #expect(existing.strictKeys == snapshot)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 0)
    }

    @Test("dedupes within the same batch and keeps the first occurrence")
    func dedupesInBatchDuplicatesKeepsFirst() async throws {
        let store = try makeStore()
        let timestamp = fixedDate(minutesOffset: 0)
        // PitchDuplicateKey hashes timestamp+notes+trainingType (not centOffset),
        // so distinct centOffsets collide as duplicates and let us verify which entry persisted.
        let entries: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [
            (timestamp, sampleDiscriminationPayload(centOffset: 11.0)),
            (timestamp, sampleDiscriminationPayload(centOffset: 22.0)),
            (timestamp, sampleDiscriminationPayload(centOffset: 33.0)),
        ]
        var existing = DuplicateKeyIndex<PitchDuplicateKey>()

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existing: &existing, keyFor: keyFor)
        }

        #expect(result.imported == 1)
        #expect(result.skipped == 2)
        #expect(existing.strictKeys.count == 1)

        let stored = try store.fetchPayloads(PitchDiscriminationPayload.self)
        #expect(stored.count == 1)
        #expect(stored.first?.payload.centOffset == 11.0)
    }

    @Test("propagates encoder errors and rolls back the transaction")
    func propagatesEncoderErrors() async throws {
        let store = try makeStore()
        let entries: [(timestamp: Date, payload: ThrowingMergePayload)] = [
            (fixedDate(minutesOffset: 0), ThrowingMergePayload(throwOnEncode: true)),
        ]
        var existing = DuplicateKeyIndex<ThrowingMergeKey>()

        #expect(throws: ThrowingMergePayload.EncodeFailure.self) {
            try store.withinTransaction { scope in
                _ = try scope.mergeImportPayloads(
                    entries,
                    existing: &existing
                ) { _, _ in ThrowingMergeKey(id: 0) }
            }
        }
        #expect(existing.strictKeys.isEmpty)
    }

    @Test("partial success before a throw rolls back inserts but leaves the index mutated")
    func partialSuccessThenThrowDocumentsAsymmetry() async throws {
        let store = try makeStore()
        let entries: [(timestamp: Date, payload: ThrowingMergePayload)] = [
            (fixedDate(minutesOffset: 0), ThrowingMergePayload(id: 0, throwOnEncode: false)),
            (fixedDate(minutesOffset: 1), ThrowingMergePayload(id: 1, throwOnEncode: true)),
            (fixedDate(minutesOffset: 2), ThrowingMergePayload(id: 2, throwOnEncode: false)),
        ]
        var existing = DuplicateKeyIndex<ThrowingMergeKey>()

        #expect(throws: ThrowingMergePayload.EncodeFailure.self) {
            try store.withinTransaction { scope in
                _ = try scope.mergeImportPayloads(
                    entries,
                    existing: &existing
                ) { _, payload in ThrowingMergeKey(id: payload.id) }
            }
        }

        // Documents the helper's contract: `existing` is inout, so the key for the
        // successfully-inserted entry 0 persists in the caller's index even though the
        // enclosing transaction rolled back the persisted envelope. Iteration 2 was
        // never reached because the loop bailed on iteration 1.
        #expect(existing.strictKeys == [ThrowingMergeKey(id: 0)])

        let storedCount = try store.fetchPayloads(ThrowingMergePayload.self).count
        #expect(storedCount == 0)
    }
}

// MARK: - Test Doubles

/// Payload that throws on encode when `throwOnEncode` is true; used to exercise the
/// helper's error and partial-success paths.
private struct ThrowingMergePayload: TrainingDisciplinePayload, Equatable {
    static let disciplineIdentifier = "throwingMerge"
    static let currentPayloadVersion = 1

    struct EncodeFailure: Error {}

    let id: Int
    let throwOnEncode: Bool

    init(id: Int = 0, throwOnEncode: Bool) {
        self.id = id
        self.throwOnEncode = throwOnEncode
    }

    func encode(to encoder: Encoder) throws {
        if throwOnEncode { throw EncodeFailure() }
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.id = try container.decode(Int.self)
        self.throwOnEncode = false
    }
}

private struct ThrowingMergeKey: Hashable {
    let id: Int
}

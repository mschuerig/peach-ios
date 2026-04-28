import Testing
import SwiftData
import Foundation
@testable import Peach

/// Covers ``TrainingDataStore/TransactionScope/mergeImportPayloads(_:existingKeys:keyFor:)``,
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

    private func sampleDiscriminationPayload(targetNote: Int = 64) -> PitchDiscriminationPayload {
        PitchDiscriminationPayload(
            referenceNote: 60,
            targetNote: targetNote,
            centOffset: 25.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament"
        )
    }

    private func keyFor(timestamp: Date, payload: PitchDiscriminationPayload) -> PitchDuplicateKey {
        PitchDuplicateKey(timestamp: timestamp, payload: payload, trainingType: "pitchDiscrimination")
    }

    // MARK: - Tests

    @Test("imports every entry when existingKeys is empty")
    func importsAllWhenSetIsEmpty() async throws {
        let store = try makeStore()
        let entries: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [
            (fixedDate(minutesOffset: 0), sampleDiscriminationPayload(targetNote: 64)),
            (fixedDate(minutesOffset: 1), sampleDiscriminationPayload(targetNote: 65)),
            (fixedDate(minutesOffset: 2), sampleDiscriminationPayload(targetNote: 66)),
        ]
        var existingKeys = Set<PitchDuplicateKey>()

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existingKeys: &existingKeys, keyFor: keyFor)
        }

        #expect(result.imported == 3)
        #expect(result.skipped == 0)
        #expect(existingKeys.count == 3)

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
        var existingKeys = Set(entries.map { keyFor(timestamp: $0.timestamp, payload: $0.payload) })

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existingKeys: &existingKeys, keyFor: keyFor)
        }

        #expect(result.imported == 0)
        #expect(result.skipped == 2)
        #expect(existingKeys.count == 2)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 0)
    }

    @Test("imports only entries whose key is not yet known")
    func importsOnlyNovelEntries() async throws {
        let store = try makeStore()
        let known = (fixedDate(minutesOffset: 0), sampleDiscriminationPayload(targetNote: 64))
        let novel1 = (fixedDate(minutesOffset: 1), sampleDiscriminationPayload(targetNote: 65))
        let novel2 = (fixedDate(minutesOffset: 2), sampleDiscriminationPayload(targetNote: 66))
        let entries = [known, novel1, novel2]
        var existingKeys: Set<PitchDuplicateKey> = [keyFor(timestamp: known.0, payload: known.1)]

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existingKeys: &existingKeys, keyFor: keyFor)
        }

        #expect(result.imported == 2)
        #expect(result.skipped == 1)
        #expect(existingKeys.count == 3)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 2)
    }

    @Test("dedupes within the same batch")
    func dedupesInBatchDuplicates() async throws {
        let store = try makeStore()
        let timestamp = fixedDate(minutesOffset: 0)
        let payload = sampleDiscriminationPayload(targetNote: 64)
        let entries: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [
            (timestamp, payload),
            (timestamp, payload),
            (timestamp, payload),
        ]
        var existingKeys = Set<PitchDuplicateKey>()

        var result: (imported: Int, skipped: Int) = (0, 0)
        try store.withinTransaction { scope in
            result = try scope.mergeImportPayloads(entries, existingKeys: &existingKeys, keyFor: keyFor)
        }

        #expect(result.imported == 1)
        #expect(result.skipped == 2)
        #expect(existingKeys.count == 1)

        let storedCount = try store.fetchPayloads(PitchDiscriminationPayload.self).count
        #expect(storedCount == 1)
    }

    @Test("propagates encoder errors and rolls back the transaction")
    func propagatesEncoderErrors() async throws {
        let store = try makeStore()
        let entries: [(timestamp: Date, payload: ThrowingMergePayload)] = [
            (fixedDate(minutesOffset: 0), ThrowingMergePayload()),
        ]
        var existingKeys = Set<ThrowingMergeKey>()

        #expect(throws: ThrowingMergePayload.EncodeFailure.self) {
            try store.withinTransaction { scope in
                _ = try scope.mergeImportPayloads(
                    entries,
                    existingKeys: &existingKeys,
                    keyFor: { _, _ in ThrowingMergeKey() }
                )
            }
        }
        #expect(existingKeys.isEmpty)
    }
}

// MARK: - Test Doubles

/// Payload that always throws when encoded; used to exercise the helper's error path.
private struct ThrowingMergePayload: TrainingDisciplinePayload, Equatable {
    static let disciplineIdentifier = "throwingMerge"
    static let currentPayloadVersion = 1

    struct EncodeFailure: Error {}

    func encode(to encoder: Encoder) throws {
        throw EncodeFailure()
    }

    init() {}

    init(from decoder: Decoder) throws {
        // Unused; the helper only encodes.
    }
}

private struct ThrowingMergeKey: Hashable {}

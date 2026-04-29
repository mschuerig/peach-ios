import Testing
import SwiftData
import Foundation
@testable import Peach

/// Streaming-iteration tests for ``TrainingDataStore/forEachPayload(_:onSkip:body:)``.
///
/// The streaming API hands one decoded payload at a time to a closure so that
/// callers iterating large payload sets never have to materialise the full
/// decoded array. These tests pin the contract: ordering, exactly-once delivery,
/// throwing-body abort behavior (wrapped in ``DataStoreError/fetchFailed(_:)``),
/// the empty-store case, and undecodable-envelope handling (logged + optional
/// onSkip callback, iteration continues).
@Suite("TrainingDataStore Streaming Iteration")
struct TrainingDataStoreStreamingTests {

    private func makeStore() throws -> TrainingDataStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TrainingRecord.self, configurations: config)
        return TrainingDataStore(modelContext: ModelContext(container))
    }

    private func envelope(
        for payload: any TrainingDisciplinePayload,
        timestamp: Date
    ) throws -> TrainingRecord {
        try JSONEnvelope.encode(payload, timestamp: timestamp)
    }

    private func payload(reference: Int) -> PitchDiscriminationPayload {
        PitchDiscriminationPayload(
            referenceNote: reference,
            targetNote: reference,
            centOffset: Double(reference),
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament"
        )
    }

    /// Builds an envelope whose disciplineIdentifier and payloadVersion match
    /// the target payload type so the descriptor predicate fetches it, but
    /// whose payloadData is malformed JSON so decode fails.
    private func corruptEnvelope<P: TrainingDisciplinePayload>(
        for type: P.Type,
        timestamp: Date
    ) -> TrainingRecord {
        TrainingRecord(
            disciplineIdentifier: P.disciplineIdentifier,
            timestamp: timestamp,
            payloadVersion: P.currentPayloadVersion,
            payloadData: Data([0xFF, 0xFE, 0xFD])
        )
    }

    @Test("forEachPayload visits payloads in timestamp-ascending order")
    func iterationOrderMatchesFetchPayloads() async throws {
        let store = try makeStore()
        let now = Date()
        // Insert out of order; the API must sort.
        try store.save(try envelope(for: payload(reference: 64), timestamp: now))
        try store.save(try envelope(for: payload(reference: 60), timestamp: now.addingTimeInterval(-60)))
        try store.save(try envelope(for: payload(reference: 62), timestamp: now.addingTimeInterval(-30)))

        var visited: [Int] = []
        try store.forEachPayload(PitchDiscriminationPayload.self) { _, payload in
            visited.append(payload.referenceNote)
        }

        #expect(visited == [60, 62, 64])
    }

    @Test("forEachPayload delivers every payload exactly once")
    func deliversEachPayloadExactlyOnce() async throws {
        let store = try makeStore()
        let now = Date()
        let references = [60, 62, 64, 65, 67, 69, 71, 72]
        for (index, reference) in references.enumerated() {
            try store.save(try envelope(
                for: payload(reference: reference),
                timestamp: now.addingTimeInterval(Double(index))
            ))
        }

        var visitCount: [Int: Int] = [:]
        try store.forEachPayload(PitchDiscriminationPayload.self) { _, payload in
            visitCount[payload.referenceNote, default: 0] += 1
        }

        #expect(visitCount.count == references.count)
        for reference in references {
            #expect(visitCount[reference] == 1)
        }
    }

    @Test("forEachPayload throwing body aborts iteration and wraps the error in DataStoreError")
    func throwingBodyAbortsIteration() async throws {
        let store = try makeStore()
        let now = Date()
        try store.save(try envelope(for: payload(reference: 60), timestamp: now.addingTimeInterval(-60)))
        try store.save(try envelope(for: payload(reference: 62), timestamp: now.addingTimeInterval(-30)))
        try store.save(try envelope(for: payload(reference: 64), timestamp: now))

        struct AbortError: LocalizedError {
            var errorDescription: String? { "abort-marker-77f2" }
        }

        var visited: [Int] = []
        var caught: Error?
        do {
            try store.forEachPayload(PitchDiscriminationPayload.self) { _, payload in
                visited.append(payload.referenceNote)
                if payload.referenceNote == 62 {
                    throw AbortError()
                }
            }
            Issue.record("forEachPayload was expected to throw but returned normally")
        } catch {
            caught = error
        }

        // body ran for 60 and 62 only; 64 was not reached.
        #expect(visited == [60, 62])
        // The wrapper is DataStoreError.fetchFailed; its description preserves the underlying error.
        let wrappedMessage = fetchFailedMessage(caught)
        #expect(wrappedMessage?.contains("abort-marker-77f2") == true,
                "Expected DataStoreError.fetchFailed wrapping the underlying error; got: \(String(describing: caught))")
    }

    @Test("forEachPayload yields zero invocations on an empty store")
    func emptyStoreYieldsZeroInvocations() async throws {
        let store = try makeStore()
        var invocationCount = 0
        try store.forEachPayload(PitchDiscriminationPayload.self) { _, _ in
            invocationCount += 1
        }
        #expect(invocationCount == 0)
    }

    @Test("forEachPayload skips undecodable envelopes and continues iteration")
    func skipsUndecodableEnvelopesAndContinues() async throws {
        let store = try makeStore()
        let now = Date()
        // Two valid envelopes flanking one corrupt envelope.
        try store.save(try envelope(for: payload(reference: 60), timestamp: now.addingTimeInterval(-60)))
        try store.save(corruptEnvelope(
            for: PitchDiscriminationPayload.self,
            timestamp: now.addingTimeInterval(-30)
        ))
        try store.save(try envelope(for: payload(reference: 64), timestamp: now))

        var visited: [Int] = []
        try store.forEachPayload(PitchDiscriminationPayload.self) { _, payload in
            visited.append(payload.referenceNote)
        }

        #expect(visited == [60, 64])
    }

    @Test("forEachPayload invokes onSkip with the timestamp of each undecodable envelope")
    func onSkipReceivesUndecodableEnvelopeTimestamps() async throws {
        let store = try makeStore()
        let now = Date()
        let corrupt1 = now.addingTimeInterval(-60)
        let corrupt2 = now.addingTimeInterval(-30)
        try store.save(corruptEnvelope(for: PitchDiscriminationPayload.self, timestamp: corrupt1))
        try store.save(corruptEnvelope(for: PitchDiscriminationPayload.self, timestamp: corrupt2))
        try store.save(try envelope(for: payload(reference: 64), timestamp: now))

        var skipped: [Date] = []
        var visited: [Int] = []
        try store.forEachPayload(
            PitchDiscriminationPayload.self,
            onSkip: { skipped.append($0) }
        ) { _, payload in
            visited.append(payload.referenceNote)
        }

        #expect(skipped == [corrupt1, corrupt2])
        #expect(visited == [64])
    }

    @Test("forEachPayload wraps a throwing onSkip callback in DataStoreError")
    func throwingOnSkipWrapsInDataStoreError() async throws {
        let store = try makeStore()
        let now = Date()
        try store.save(corruptEnvelope(for: PitchDiscriminationPayload.self, timestamp: now))

        struct OnSkipError: LocalizedError {
            var errorDescription: String? { "onskip-marker-3a1b" }
        }

        var caught: Error?
        do {
            try store.forEachPayload(
                PitchDiscriminationPayload.self,
                onSkip: { _ in throw OnSkipError() }
            ) { _, _ in
                Issue.record("body should not be invoked when the only envelope is undecodable")
            }
            Issue.record("forEachPayload was expected to throw but returned normally")
        } catch {
            caught = error
        }

        let wrappedMessage = fetchFailedMessage(caught)
        #expect(wrappedMessage?.contains("onskip-marker-3a1b") == true,
                "Expected DataStoreError.fetchFailed wrapping the underlying error; got: \(String(describing: caught))")
    }
}

/// Returns the wrapped message if `error` is `DataStoreError.fetchFailed(_)`,
/// otherwise nil.
private func fetchFailedMessage(_ error: Error?) -> String? {
    guard let dataStoreError = error as? Peach.DataStoreError else { return nil }
    switch dataStoreError {
    case .fetchFailed(let message):
        return message
    default:
        return nil
    }
}

import Testing
import SwiftData
import Foundation
@testable import Peach

/// Streaming-iteration tests for ``TrainingDataStore/forEachPayload(_:body:)``.
///
/// The streaming API hands one decoded payload at a time to a closure so that
/// callers iterating large payload sets never have to materialise the full
/// decoded array. These tests pin the contract: ordering, exactly-once delivery,
/// throwing-body propagation, and the empty-store case.
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

        let expected = try store.fetchPayloads(PitchDiscriminationPayload.self).map { $0.payload.referenceNote }
        #expect(visited == [60, 62, 64])
        #expect(visited == expected)
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

    @Test("forEachPayload throwing body aborts iteration and propagates the error")
    func throwingBodyAbortsIteration() async throws {
        let store = try makeStore()
        let now = Date()
        try store.save(try envelope(for: payload(reference: 60), timestamp: now.addingTimeInterval(-60)))
        try store.save(try envelope(for: payload(reference: 62), timestamp: now.addingTimeInterval(-30)))
        try store.save(try envelope(for: payload(reference: 64), timestamp: now))

        struct AbortError: Error, Equatable {}

        var visited: [Int] = []
        do {
            try store.forEachPayload(PitchDiscriminationPayload.self) { _, payload in
                visited.append(payload.referenceNote)
                if payload.referenceNote == 62 {
                    throw AbortError()
                }
            }
            Issue.record("forEachPayload was expected to throw but returned normally")
        } catch is AbortError {
            // expected
        }

        // body ran for 60 and 62 only; 64 was not reached.
        #expect(visited == [60, 62])
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
}

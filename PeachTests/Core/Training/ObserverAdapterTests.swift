import Testing
import SwiftData
import Foundation
@testable import Peach

// MARK: - Mock ProfileUpdating

private final class MockProfileUpdating: ProfileUpdating {
    var updates: [(key: StatisticsKey, timestamp: Date, value: Double)] = []

    func update(_ key: StatisticsKey, timestamp: Date, value: Double) {
        updates.append((key, timestamp, value))
    }
}

// MARK: - Mock TrainingRecordPersisting

private final class MockRecordPersisting: TrainingRecordPersisting {
    var savedRecords: [any PersistentModel] = []
    var saveCallCount = 0
    var errorToThrow: (any Error)?

    func save(_ record: some PersistentModel) throws {
        if let error = errorToThrow { throw error }
        saveCallCount += 1
        savedRecords.append(record)
    }
}

// MARK: - Profile Adapter Tests

@Suite("Profile Adapter Tests")
struct ProfileAdapterTests {

    private func fixedDate() -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000)
    }

    // MARK: - PitchDiscriminationProfileAdapter

    @Test("PitchDiscrimination profile adapter updates unison key for correct unison trial")
    func pitchDiscriminationProfileAdapterUnison() async {
        let profile = MockProfileUpdating()
        let adapter = PitchDiscriminationProfileAdapter(profile: profile)

        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(60), offset: Cents(15))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament,
            timestamp: fixedDate()
        )

        adapter.pitchDiscriminationCompleted(completed)

        #expect(profile.updates.count == 1)
        #expect(profile.updates[0].key == .pitch(.unisonPitchDiscrimination))
        #expect(profile.updates[0].value == 15.0)
    }

    @Test("PitchDiscrimination profile adapter updates interval key for correct interval trial")
    func pitchDiscriminationProfileAdapterInterval() async {
        let profile = MockProfileUpdating()
        let adapter = PitchDiscriminationProfileAdapter(profile: profile)

        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(-10))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: false,
            tuningSystem: .equalTemperament,
            timestamp: fixedDate()
        )

        adapter.pitchDiscriminationCompleted(completed)

        #expect(profile.updates.count == 1)
        #expect(profile.updates[0].key == .pitch(.intervalPitchDiscrimination))
        #expect(profile.updates[0].value == 10.0)
    }

    @Test("PitchDiscrimination profile adapter does not update profile on incorrect answer")
    func pitchDiscriminationProfileAdapterIncorrect() async {
        let profile = MockProfileUpdating()
        let adapter = PitchDiscriminationProfileAdapter(profile: profile)

        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(60), offset: Cents(15))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: false,
            tuningSystem: .equalTemperament,
            timestamp: fixedDate()
        )

        adapter.pitchDiscriminationCompleted(completed)

        #expect(profile.updates.isEmpty)
    }

    // MARK: - PitchMatchingProfileAdapter

    @Test("PitchMatching profile adapter updates unison key for unison trial")
    func pitchMatchingProfileAdapterUnison() async {
        let profile = MockProfileUpdating()
        let adapter = PitchMatchingProfileAdapter(profile: profile)

        let completed = CompletedPitchMatchingTrial(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(60),
            initialCentOffset: Cents(25),
            userCentError: Cents(-3.5),
            tuningSystem: .equalTemperament,
            timestamp: fixedDate()
        )

        adapter.pitchMatchingCompleted(completed)

        #expect(profile.updates.count == 1)
        #expect(profile.updates[0].key == .pitch(.unisonPitchMatching))
        #expect(profile.updates[0].value == 3.5)
    }

    @Test("PitchMatching profile adapter updates interval key for interval trial")
    func pitchMatchingProfileAdapterInterval() async {
        let profile = MockProfileUpdating()
        let adapter = PitchMatchingProfileAdapter(profile: profile)

        let completed = CompletedPitchMatchingTrial(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(67),
            initialCentOffset: Cents(25),
            userCentError: Cents(2.0),
            tuningSystem: .equalTemperament,
            timestamp: fixedDate()
        )

        adapter.pitchMatchingCompleted(completed)

        #expect(profile.updates.count == 1)
        #expect(profile.updates[0].key == .pitch(.intervalPitchMatching))
        #expect(profile.updates[0].value == 2.0)
    }

    // MARK: - TimingOffsetDetectionProfileAdapter

    @Test("TimingOffsetDetection profile adapter updates correct key for correct late trial")
    func rhythmOffsetDetectionProfileAdapterLate() async {
        let profile = MockProfileUpdating()
        let adapter = TimingOffsetDetectionProfileAdapter(profile: profile)

        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(100),
            offset: TimingOffset(.milliseconds(12.5)),
            isCorrect: true,
            timestamp: fixedDate()
        )

        adapter.timingOffsetDetectionCompleted(result)

        #expect(profile.updates.count == 1)
        #expect(profile.updates[0].key == .rhythm(.timingOffsetDetection, .brisk, .late))
        #expect(profile.updates[0].value == 12.5)
    }

    @Test("TimingOffsetDetection profile adapter updates correct key for correct early trial")
    func rhythmOffsetDetectionProfileAdapterEarly() async {
        let profile = MockProfileUpdating()
        let adapter = TimingOffsetDetectionProfileAdapter(profile: profile)

        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(60),
            offset: TimingOffset(.milliseconds(-8.0)),
            isCorrect: true,
            timestamp: fixedDate()
        )

        adapter.timingOffsetDetectionCompleted(result)

        #expect(profile.updates.count == 1)
        #expect(profile.updates[0].key == .rhythm(.timingOffsetDetection, .slow, .early))
        #expect(profile.updates[0].value == 8.0)
    }

    @Test("TimingOffsetDetection profile adapter does not update profile on incorrect answer")
    func rhythmOffsetDetectionProfileAdapterIncorrect() async {
        let profile = MockProfileUpdating()
        let adapter = TimingOffsetDetectionProfileAdapter(profile: profile)

        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(100),
            offset: TimingOffset(.milliseconds(12.5)),
            isCorrect: false,
            timestamp: fixedDate()
        )

        adapter.timingOffsetDetectionCompleted(result)

        #expect(profile.updates.isEmpty)
    }

    // MARK: - ContinuousRhythmMatchingProfileAdapter

    @Test("ContinuousRhythmMatching profile adapter updates correct key for late mean")
    func continuousRhythmMatchingProfileAdapterLate() async {
        let profile = MockProfileUpdating()
        let adapter = ContinuousRhythmMatchingProfileAdapter(profile: profile)

        let result = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(100),
            gapResults: [
                GapResult(position: .first, offset: TimingOffset(.milliseconds(10))),
                GapResult(position: .second, offset: TimingOffset(.milliseconds(20))),
            ],
            timestamp: fixedDate()
        )

        adapter.continuousRhythmMatchingCompleted(result)

        #expect(profile.updates.count == 1)
        #expect(profile.updates[0].key == .rhythm(.continuousRhythmMatching, .brisk, .late))
        #expect(profile.updates[0].value == 15.0)
    }

    @Test("ContinuousRhythmMatching profile adapter does not update for empty gap results")
    func continuousRhythmMatchingProfileAdapterEmpty() async {
        let profile = MockProfileUpdating()
        let adapter = ContinuousRhythmMatchingProfileAdapter(profile: profile)

        let result = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(100),
            gapResults: [],
            timestamp: fixedDate()
        )

        adapter.continuousRhythmMatchingCompleted(result)

        #expect(profile.updates.isEmpty)
    }
}

// MARK: - Store Adapter Tests

@Suite("Store Adapter Tests")
struct StoreAdapterTests {

    private func fixedDate() -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000)
    }

    // MARK: - PitchDiscriminationStoreAdapter

    @Test("PitchDiscrimination store adapter creates and saves correct record")
    func pitchDiscriminationStoreAdapter() async throws {
        let store = MockRecordPersisting()
        let adapter = PitchDiscriminationStoreAdapter(store: store)

        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(15))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament,
            timestamp: fixedDate()
        )

        adapter.pitchDiscriminationCompleted(completed)

        #expect(store.saveCallCount == 1)
        let saved = try #require(store.savedRecords[0] as? PitchDiscriminationRecord)
        #expect(saved.referenceNote == 60)
        #expect(saved.targetNote == 67)
        #expect(saved.centOffset == 15.0)
        #expect(saved.interval == 7)
        #expect(saved.tuningSystem == "equalTemperament")
        #expect(saved.timestamp == fixedDate())
    }

    // MARK: - PitchMatchingStoreAdapter

    @Test("PitchMatching store adapter creates and saves correct record")
    func pitchMatchingStoreAdapter() async throws {
        let store = MockRecordPersisting()
        let adapter = PitchMatchingStoreAdapter(store: store)

        let completed = CompletedPitchMatchingTrial(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(67),
            initialCentOffset: Cents(25),
            userCentError: Cents(-3.5),
            tuningSystem: .equalTemperament,
            timestamp: fixedDate()
        )

        adapter.pitchMatchingCompleted(completed)

        #expect(store.saveCallCount == 1)
        let saved = try #require(store.savedRecords[0] as? PitchMatchingRecord)
        #expect(saved.referenceNote == 60)
        #expect(saved.targetNote == 67)
        #expect(saved.initialCentOffset == 25.0)
        #expect(saved.userCentError == -3.5)
        #expect(saved.interval == 7)
        #expect(saved.tuningSystem == "equalTemperament")
        #expect(saved.timestamp == fixedDate())
    }

    // MARK: - TimingOffsetDetectionStoreAdapter

    @Test("TimingOffsetDetection store adapter creates and saves correct record")
    func rhythmOffsetDetectionStoreAdapter() async throws {
        let store = MockRecordPersisting()
        let adapter = TimingOffsetDetectionStoreAdapter(store: store)

        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: TimingOffset(.milliseconds(-8.5)),
            isCorrect: true,
            timestamp: fixedDate()
        )

        adapter.timingOffsetDetectionCompleted(result)

        #expect(store.saveCallCount == 1)
        let saved = try #require(store.savedRecords[0] as? TimingOffsetDetectionRecord)
        #expect(saved.tempoBPM == 120)
        #expect(saved.offsetMs == -8.5)
        #expect(saved.isCorrect == true)
        #expect(saved.timestamp == fixedDate())
    }

    // MARK: - ContinuousRhythmMatchingStoreAdapter

    @Test("ContinuousRhythmMatching store adapter creates record with position means")
    func continuousRhythmMatchingStoreAdapter() async throws {
        let store = MockRecordPersisting()
        let adapter = ContinuousRhythmMatchingStoreAdapter(store: store)

        let result = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(100),
            gapResults: [
                GapResult(position: .first, offset: TimingOffset(.milliseconds(10))),
                GapResult(position: .first, offset: TimingOffset(.milliseconds(20))),
                GapResult(position: .second, offset: TimingOffset(.milliseconds(-5))),
            ],
            timestamp: fixedDate()
        )

        adapter.continuousRhythmMatchingCompleted(result)

        #expect(store.saveCallCount == 1)
        let saved = try #require(store.savedRecords[0] as? ContinuousRhythmMatchingRecord)
        #expect(saved.tempoBPM == 100)
        #expect(saved.meanOffsetMsPosition0 == 15.0)
        #expect(saved.meanOffsetMsPosition1 == -5.0)
        #expect(saved.meanOffsetMsPosition2 == nil)
        #expect(saved.meanOffsetMsPosition3 == nil)
        #expect(saved.timestamp == fixedDate())
    }

    // MARK: - Store Adapter Error Handling

    @Test("PitchDiscrimination store adapter does not throw on save error")
    func pitchDiscriminationStoreAdapterSaveError() async {
        let store = MockRecordPersisting()
        store.errorToThrow = DataStoreError.saveFailed("test")
        let adapter = PitchDiscriminationStoreAdapter(store: store)

        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(15))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial, userAnsweredHigher: true,
            tuningSystem: .equalTemperament, timestamp: fixedDate()
        )

        adapter.pitchDiscriminationCompleted(completed)

        #expect(store.saveCallCount == 0)
    }

    @Test("PitchMatching store adapter does not throw on save error")
    func pitchMatchingStoreAdapterSaveError() async {
        let store = MockRecordPersisting()
        store.errorToThrow = DataStoreError.saveFailed("test")
        let adapter = PitchMatchingStoreAdapter(store: store)

        let completed = CompletedPitchMatchingTrial(
            referenceNote: MIDINote(60), targetNote: MIDINote(67),
            initialCentOffset: Cents(25), userCentError: Cents(-3.5),
            tuningSystem: .equalTemperament, timestamp: fixedDate()
        )

        adapter.pitchMatchingCompleted(completed)

        #expect(store.saveCallCount == 0)
    }

    @Test("TimingOffsetDetection store adapter does not throw on save error")
    func rhythmOffsetDetectionStoreAdapterSaveError() async {
        let store = MockRecordPersisting()
        store.errorToThrow = DataStoreError.saveFailed("test")
        let adapter = TimingOffsetDetectionStoreAdapter(store: store)

        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(120), offset: TimingOffset(.milliseconds(-8.5)),
            isCorrect: true, timestamp: fixedDate()
        )

        adapter.timingOffsetDetectionCompleted(result)

        #expect(store.saveCallCount == 0)
    }

    @Test("ContinuousRhythmMatching store adapter does not throw on save error")
    func continuousRhythmMatchingStoreAdapterSaveError() async {
        let store = MockRecordPersisting()
        store.errorToThrow = DataStoreError.saveFailed("test")
        let adapter = ContinuousRhythmMatchingStoreAdapter(store: store)

        let result = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(100),
            gapResults: [GapResult(position: .first, offset: TimingOffset(.milliseconds(10)))],
            timestamp: fixedDate()
        )

        adapter.continuousRhythmMatchingCompleted(result)

        #expect(store.saveCallCount == 0)
    }
}

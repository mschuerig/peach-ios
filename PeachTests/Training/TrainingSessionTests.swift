import Testing
import Foundation
@testable import Peach

/// Comprehensive tests for TrainingSession state machine and training loop
@Suite("TrainingSession Tests")
struct TrainingSessionTests {

    // MARK: - Test Fixtures

    @MainActor
    func makeTrainingSession(
        comparisons: [Comparison] = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 95.0, isSecondNoteHigher: false)
        ]
    ) -> (TrainingSession, MockNotePlayer, MockTrainingDataStore, PerceptualProfile, MockNextNoteStrategy) {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: comparisons)
        let observers: [ComparisonObserver] = [mockDataStore, profile]
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0,
            observers: observers
        )
        return (session, mockPlayer, mockDataStore, profile, mockStrategy)
    }

    // MARK: - Test Helpers

    /// Waits for the session to reach a specific state (or timeout after 1 second)
    @MainActor
    func waitForState(_ session: TrainingSession, _ expectedState: TrainingState, timeout: Duration = .seconds(1)) async throws {
        // First, yield to allow any pending async tasks to progress
        await Task.yield()

        // Check immediately after yield - with instant playback, state should be ready
        if session.state == expectedState {
            return
        }

        // If not ready yet, poll with short intervals
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if session.state == expectedState {
                return
            }
            try await Task.sleep(for: .milliseconds(5))  // Reduced from 10ms to 5ms
            await Task.yield()  // Yield to allow state machine to progress
        }
        Issue.record("Timeout waiting for state \(expectedState), current state: \(session.state)")
    }

    /// Waits for mock player to reach a minimum play call count
    @MainActor
    func waitForPlayCallCount(_ mockPlayer: MockNotePlayer, _ minCount: Int, timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if mockPlayer.playCallCount >= minCount {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
            await Task.yield()
        }
        Issue.record("Timeout waiting for playCallCount >= \(minCount), current: \(mockPlayer.playCallCount)")
    }

    // MARK: - State Transition Tests

    @MainActor
    @Test("TrainingSession starts in idle state")
    func startsInIdleState() {
        let (session, _, _, _, _) = makeTrainingSession()
        #expect(session.state == .idle)
    }

    @MainActor
    @Test("startTraining transitions from idle to playingNote1")
    func startTrainingTransitionsToPlayingNote1() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        var capturedState: TrainingState?
        mockPlayer.onPlayCalled = {
            // Capture state synchronously when play() is called
            if capturedState == nil {  // Only capture first call
                capturedState = session.state
            }
        }

        session.startTraining()
        await Task.yield()  // Let training task start

        #expect(capturedState == .playingNote1)
        #expect(mockPlayer.playCallCount >= 1)
    }

    @MainActor
    @Test("TrainingSession transitions from playingNote1 to playingNote2")
    func transitionsFromNote1ToNote2() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()
        mockPlayer.simulatedPlaybackDuration = 0.02  // 20ms

        session.startTraining()

        // Wait for first note to complete
        try? await Task.sleep(for: .milliseconds(50))

        // Should have played note 1 and started note 2
        #expect(mockPlayer.playCallCount >= 1)
        #expect(session.state == .playingNote2 || session.state == .awaitingAnswer)
    }

    @MainActor
    @Test("TrainingSession transitions from playingNote2 to awaitingAnswer")
    func transitionsFromNote2ToAwaitingAnswer() async {
        let (session, _, _, _, _) = makeTrainingSession()

        session.startTraining()

        // Wait for both notes to complete
        try? await Task.sleep(for: .milliseconds(100))

        #expect(session.state == .awaitingAnswer || session.state == .showingFeedback)
    }

    @MainActor
    @Test("handleAnswer transitions to showingFeedback")
    func handleAnswerTransitionsToShowingFeedback() async throws {
        let (session, _, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        #expect(session.state == .showingFeedback)
    }

    @MainActor
    @Test("TrainingSession loops back to playingNote1 after feedback")
    func loopsBackAfterFeedback() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)
        #expect(session.state == .showingFeedback)

        // Wait for next comparison to start (feedback clears + new notes play)
        try await waitForPlayCallCount(mockPlayer, 3)  // note1, note2, next note1

        // Should have looped back and started next comparison
        #expect(mockPlayer.playCallCount >= 3)  // At least note1, note2, next note1
    }

    @MainActor
    @Test("stop() transitions to idle from any state")
    func stopTransitionsToIdle() async {
        let (session, _, _, _, _) = makeTrainingSession()

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(50))

        session.stop()

        #expect(session.state == .idle)
    }

    @MainActor
    @Test("Audio error transitions to idle")
    func audioErrorTransitionsToIdle() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()
        mockPlayer.shouldThrowError = true
        mockPlayer.errorToThrow = .renderFailed("Test error")

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(session.state == .idle)
    }

    // MARK: - NotePlayer Integration Tests

    @MainActor
    @Test("TrainingSession calls play twice per comparison")
    func callsPlayTwicePerComparison() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(mockPlayer.playCallCount == 2)  // note1 and note2
    }

    @MainActor
    @Test("TrainingSession uses correct frequency calculation")
    func usesCorrectFrequencyCalculation() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Verify frequencies were calculated and passed to player
        #expect(mockPlayer.lastFrequency != nil)
        #expect(mockPlayer.lastFrequency! > 0)

        // Frequency should be in audible range for MIDI 48-72 (roughly 130-1047 Hz)
        #expect(mockPlayer.lastFrequency! >= 100 && mockPlayer.lastFrequency! <= 1200)
    }

    @MainActor
    @Test("TrainingSession passes correct duration to NotePlayer")
    func passesCorrectDuration() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(mockPlayer.lastDuration == 1.0)  // Default 1 second duration
    }

    @MainActor
    @Test("TrainingSession passes correct amplitude to NotePlayer")
    func passesCorrectAmplitude() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(mockPlayer.lastAmplitude == 0.5)  // Default amplitude
    }

    // MARK: - TrainingDataStore Integration Tests

    @MainActor
    @Test("TrainingSession records comparison on answer")
    func recordsComparisonOnAnswer() async throws {
        let (session, _, mockDataStore, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        #expect(mockDataStore.saveCallCount == 1)
        #expect(mockDataStore.lastSavedRecord != nil)
    }

    @MainActor
    @Test("ComparisonRecord contains correct note data")
    func comparisonRecordContainsCorrectData() async throws {
        let (session, _, mockDataStore, _, _) = makeTrainingSession()

        session.startTraining()

        // Wait for awaitingAnswer state before calling handleAnswer
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: false)

        let record = mockDataStore.lastSavedRecord!
        // MockNextNoteStrategy returns note1=60, note2=60, centDifference=100.0, isSecondNoteHigher=true
        #expect(record.note1 == 60)
        #expect(record.note2 == 60)
        // isSecondNoteHigher=true → centOffset is positive 100.0
        #expect(record.note2CentOffset == 100.0)
    }

    @MainActor
    @Test("Data error does not stop training")
    func dataErrorDoesNotStopTraining() async throws {
        let (session, mockPlayer, mockDataStore, _, _) = makeTrainingSession()
        mockDataStore.shouldThrowError = true

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        // Should continue to feedback state despite save error
        #expect(session.state == .showingFeedback)

        // Wait for next comparison to start (feedback clears + new notes play)
        try await waitForPlayCallCount(mockPlayer, 3)  // note1, note2, next note1

        // Training should have continued with next comparison
        #expect(mockPlayer.playCallCount >= 3)
    }

    // MARK: - Timing and Coordination Tests

    @MainActor
    @Test("Buttons disabled during playingNote1")
    func buttonsDisabledDuringNote1() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        var capturedState: TrainingState?
        mockPlayer.onPlayCalled = {
            // Capture state synchronously when play() is called
            if capturedState == nil {  // Only capture first call (note1)
                capturedState = session.state
            }
        }

        session.startTraining()
        await Task.yield()  // Let training task start

        #expect(capturedState == .playingNote1)
    }

    @MainActor
    @Test("Buttons enabled during playingNote2 and awaitingAnswer")
    func buttonsEnabledDuringNote2AndWaiting() async {
        let (session, _, _, _, _) = makeTrainingSession()

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        let state = session.state
        // Buttons should be enabled when state is playingNote2 or awaitingAnswer
        #expect(state == .playingNote2 || state == .awaitingAnswer)
    }

    @MainActor
    @Test("TrainingSession completes full comparison loop")
    func completesFullLoop() async {
        let (session, mockPlayer, mockDataStore, _, _) = makeTrainingSession()

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Answer first comparison
        session.handleAnswer(isHigher: true)

        // Wait for feedback and next comparison
        try? await Task.sleep(for: .milliseconds(600))

        // Should have completed loop and started next comparison
        #expect(mockPlayer.playCallCount >= 3)  // note1, note2, next note1
        #expect(mockDataStore.saveCallCount == 1)
    }

    // MARK: - Comparison Value Type Tests

    @Test("Comparison.note1Frequency calculates valid frequency")
    func note1FrequencyCalculatesCorrectly() throws {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)

        let freq = try comparison.note1Frequency()

        // Middle C (MIDI 60) should be ~261.63 Hz at A440
        #expect(freq >= 260 && freq <= 263)
    }

    @Test("Comparison.note2Frequency applies cent offset higher")
    func note2FrequencyAppliesCentOffsetHigher() throws {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)

        let freq1 = try comparison.note1Frequency()
        let freq2 = try comparison.note2Frequency()

        // Second note should be higher
        #expect(freq2 > freq1)

        // Difference should be approximately 1 semitone (about 6% higher)
        let ratio = freq2 / freq1
        #expect(ratio >= 1.05 && ratio <= 1.07)
    }

    @Test("Comparison.note2Frequency applies cent offset lower")
    func note2FrequencyAppliesCentOffsetLower() throws {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: false)

        let freq1 = try comparison.note1Frequency()
        let freq2 = try comparison.note2Frequency()

        // Second note should be lower
        #expect(freq2 < freq1)
    }

    @Test("Comparison.isCorrect validates user answer correctly")
    func isCorrectValidatesAnswer() {
        let comparisonHigher = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)
        let comparisonLower = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: false)

        #expect(comparisonHigher.isCorrect(userAnswerHigher: true) == true)
        #expect(comparisonHigher.isCorrect(userAnswerHigher: false) == false)
        #expect(comparisonLower.isCorrect(userAnswerHigher: false) == true)
        #expect(comparisonLower.isCorrect(userAnswerHigher: true) == false)
    }

    // MARK: - Integration Tests: PerceptualProfile Updates (Story 4.1)

    @MainActor
    @Test("Profile is updated incrementally when comparison is recorded")
    func profileUpdatesIncrementallyAfterComparison() async {
        // Mock returns: note1=60, centDifference=100.0, isSecondNoteHigher=true
        let (session, _, mockDataStore, profile, _) = makeTrainingSession()

        // Start training
        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Answer "higher" (correct, since isSecondNoteHigher=true)
        session.handleAnswer(isHigher: true)
        try? await Task.sleep(for: .milliseconds(100))

        // Verify comparison was recorded
        guard mockDataStore.lastSavedRecord != nil else {
            Issue.record("No comparison was recorded")
            return
        }

        // Verify profile was updated for note 60 with +100 cents (higher direction)
        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 1)
        #expect(stats.mean == 100.0)
    }

    @MainActor
    @Test("Profile updates preserve directional bias (signed centOffset)")
    func profilePreservesDirectionalBias() async {
        let (_, _, _, profile, _) = makeTrainingSession()

        // Manually update profile with directional data
        profile.update(note: 60, centOffset: 50.0, isCorrect: true)   // Higher
        profile.update(note: 60, centOffset: -30.0, isCorrect: true)  // Lower

        // Mean should reflect signed values: (50 + -30) / 2 = 10
        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 2)
        #expect(stats.mean == 10.0)
    }

    @MainActor
    @Test("Profile statistics accumulate correctly over multiple comparisons")
    func profileAccumulatesMultipleComparisons() async {
        // Two comparisons: note 60 (higher, 100 cents) then note 62 (lower, 95 cents)
        let (session, _, mockDataStore, profile, _) = makeTrainingSession()

        // Start training
        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Answer first comparison (note 60, isSecondNoteHigher=true, answer "higher" = correct)
        session.handleAnswer(isHigher: true)
        try? await Task.sleep(for: .milliseconds(600))  // Wait for feedback + next comparison

        // Answer second comparison (note 62, isSecondNoteHigher=false, answer "lower" = correct)
        session.handleAnswer(isHigher: false)
        try? await Task.sleep(for: .milliseconds(100))

        // Verify two comparisons were recorded
        #expect(mockDataStore.savedRecords.count == 2)

        // First comparison: note 60, centOffset = +100 (isSecondNoteHigher=true)
        let stats60 = profile.statsForNote(60)
        #expect(stats60.sampleCount == 1)
        #expect(stats60.mean == 100.0)

        // Second comparison: note 62, centOffset = -95 (isSecondNoteHigher=false)
        let stats62 = profile.statsForNote(62)
        #expect(stats62.sampleCount == 1)
        #expect(stats62.mean == -95.0)
    }

    @MainActor
    @Test("Profile updates for all answers (both correct and incorrect)")
    func profileUpdatesForAllAnswers() async {
        // Mock returns: note1=60, centDifference=100.0, isSecondNoteHigher=true
        let (session, _, mockDataStore, profile, _) = makeTrainingSession()

        // Start training
        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Answer incorrectly (say "lower" when second note is higher)
        session.handleAnswer(isHigher: false)
        try? await Task.sleep(for: .milliseconds(100))

        guard mockDataStore.lastSavedRecord != nil else {
            Issue.record("No comparison was recorded")
            return
        }

        // Profile SHOULD be updated regardless of correctness
        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 1, "Profile should update for all answers, not just correct ones")
        #expect(stats.mean == 100.0)  // +100 cents (isSecondNoteHigher=true)
    }

    // MARK: - Integration Tests: Settings Propagation (Story 4.3)

    @MainActor
    @Test("Strategy receives correct settings")
    func strategyReceivesCorrectSettings() async {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()
        let customSettings = TrainingSettings(
            noteRangeMin: 48,
            noteRangeMax: 72,
            naturalVsMechanical: 0.8
        )
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: customSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Strategy should have received the custom settings
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 72)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.8)
    }

    @MainActor
    @Test("Strategy receives updated profile after answer")
    func strategyReceivesUpdatedProfileAfterAnswer() async {
        let (session, _, _, profile, mockStrategy) = makeTrainingSession()

        // Start training — first comparison requested
        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(mockStrategy.callCount == 1)

        // Answer triggers profile update + next comparison
        session.handleAnswer(isHigher: true)
        try? await Task.sleep(for: .milliseconds(600))

        // Second comparison should have been requested with same (now-updated) profile
        #expect(mockStrategy.callCount == 2)
        #expect(mockStrategy.lastReceivedProfile === profile)

        // Profile should have been updated before second call
        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 1)
    }

    // MARK: - Integration Tests: Profile Loading from DataStore (Story 4.3 AC#2)

    @MainActor
    @Test("Profile loaded from pre-populated data store reflects stored records")
    func profileLoadedFromDataStore() async {
        // Simulate app startup: populate profile from existing records
        let profile = PerceptualProfile()
        let records = [
            ComparisonRecord(note1: 60, note2: 60, note2CentOffset: 50.0, isCorrect: true, timestamp: Date()),
            ComparisonRecord(note1: 60, note2: 60, note2CentOffset: 30.0, isCorrect: true, timestamp: Date()),
            ComparisonRecord(note1: 62, note2: 62, note2CentOffset: -40.0, isCorrect: false, timestamp: Date())
        ]

        for record in records {
            profile.update(note: record.note1, centOffset: record.note2CentOffset, isCorrect: record.isCorrect)
        }

        // Verify profile populated correctly
        let stats60 = profile.statsForNote(60)
        #expect(stats60.sampleCount == 2)
        #expect(stats60.mean == 40.0)  // (50 + 30) / 2

        let stats62 = profile.statsForNote(62)
        #expect(stats62.sampleCount == 1)
        #expect(stats62.mean == -40.0)
    }

    // MARK: - Integration Tests: Cold Start (Story 4.3)

    @MainActor
    @Test("Cold start with empty profile uses default difficulty")
    func coldStartWithEmptyProfile() async {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        // Cold start: no training data
        let comparison = strategy.nextComparison(
            profile: profile,
            settings: TrainingSettings(),
            lastComparison: nil
        )

        // Cold start should use default 100 cent difficulty
        #expect(comparison.centDifference == 100.0)
        // Note should be within default range
        #expect(comparison.note1 >= 36 && comparison.note1 <= 84)
    }

    // MARK: - Story 6.2: Settings Override Tests (no UserDefaults interaction)

    @MainActor
    @Test("TrainingSession with settingsOverride uses override values")
    func settingsOverrideUsesOverrideValues() async {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()
        let overrideSettings = TrainingSettings(
            noteRangeMin: 48,
            noteRangeMax: 72,
            naturalVsMechanical: 0.3,
            referencePitch: 432.0
        )
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: overrideSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Strategy should have received the override settings
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 72)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.3)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 432.0)
    }

    @MainActor
    @Test("noteDurationOverride takes precedence over UserDefaults")
    func noteDurationOverrideTakesPrecedence() async {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        // Provide an override — UserDefaults value irrelevant
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 0.5,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Override should win
        #expect(mockPlayer.lastDuration == 0.5)
    }
}

// MARK: - Story 6.2: Live Settings via UserDefaults (serialized to avoid shared state conflicts)

@Suite("TrainingSession UserDefaults Settings Tests", .serialized)
struct TrainingSessionUserDefaultsTests {

    /// Removes all settings keys from UserDefaults to ensure test isolation
    func cleanUpSettingsDefaults() {
        let keys = [
            SettingsKeys.naturalVsMechanical,
            SettingsKeys.noteRangeMin,
            SettingsKeys.noteRangeMax,
            SettingsKeys.noteDuration,
            SettingsKeys.referencePitch,
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @MainActor
    @Test("Changing UserDefaults values changes TrainingSettings built by TrainingSession")
    func userDefaultsChangesAffectSettings() async {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        // Set custom values in UserDefaults before creating session
        UserDefaults.standard.set(0.8, forKey: SettingsKeys.naturalVsMechanical)
        UserDefaults.standard.set(50, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(70, forKey: SettingsKeys.noteRangeMax)
        UserDefaults.standard.set(432.0, forKey: SettingsKeys.referencePitch)

        // No settingsOverride — uses UserDefaults (production mode)
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Strategy should receive the UserDefaults values
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 50)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 70)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.8)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 432.0)

        session.stop()
    }

    @MainActor
    @Test("Note duration from UserDefaults is passed to NotePlayer")
    func noteDurationFromUserDefaultsPassedToPlayer() async {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        // Set custom note duration before creating session
        UserDefaults.standard.set(2.5, forKey: SettingsKeys.noteDuration)

        // No overrides — uses UserDefaults
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // NotePlayer should have received the custom duration
        #expect(mockPlayer.lastDuration == 2.5)

        session.stop()
    }

    @MainActor
    @Test("Reference pitch from UserDefaults is passed to frequency calculation")
    func referencePitchFromUserDefaultsAffectsFrequency() async {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: [
            Comparison(note1: 69, note2: 69, centDifference: 100.0, isSecondNoteHigher: true)
        ])

        // Set reference pitch to 432 Hz before creating session
        UserDefaults.standard.set(432.0, forKey: SettingsKeys.referencePitch)

        // No overrides — uses UserDefaults
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Note 69 (A4) at referencePitch 432 should produce ~432 Hz for note1
        #expect(mockPlayer.playHistory.count >= 1)
        let note1Freq = mockPlayer.playHistory[0].frequency
        // A4 at 432Hz reference should be exactly 432.0
        #expect(abs(note1Freq - 432.0) < 0.01)

        session.stop()
    }

    @MainActor
    @Test("Settings persist across simulated app restart")
    func settingsPersistAcrossRestart() async {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        // Simulate user changing settings
        UserDefaults.standard.set(0.9, forKey: SettingsKeys.naturalVsMechanical)
        UserDefaults.standard.set(55, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(75, forKey: SettingsKeys.noteRangeMax)
        UserDefaults.standard.set(1.5, forKey: SettingsKeys.noteDuration)
        UserDefaults.standard.set(415.0, forKey: SettingsKeys.referencePitch)

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        // "Restart": create a new TrainingSession (no settingsOverride)
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Verify the new session picked up persisted settings
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 55)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 75)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.9)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 415.0)
        #expect(mockPlayer.lastDuration == 1.5)

        session.stop()
    }

    @MainActor
    @Test("Settings changed mid-training take effect on next comparison")
    func settingsChangedMidTrainingTakeEffect() async throws {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 95.0, isSecondNoteHigher: false)
        ])

        // Start with default settings (no UserDefaults overrides)
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try? await Task.sleep(for: .milliseconds(100))

        // Comparison 1 should use defaults
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == SettingsKeys.defaultNoteRangeMin)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == SettingsKeys.defaultNaturalVsMechanical)

        // Change settings MID-TRAINING (simulating user changing settings between comparisons)
        UserDefaults.standard.set(50, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(70, forKey: SettingsKeys.noteRangeMax)
        UserDefaults.standard.set(0.9, forKey: SettingsKeys.naturalVsMechanical)
        UserDefaults.standard.set(2.0, forKey: SettingsKeys.noteDuration)

        // Answer comparison 1 to trigger next comparison
        session.handleAnswer(isHigher: true)
        try? await Task.sleep(for: .milliseconds(600))

        // Comparison 2 should pick up the NEW settings
        #expect(mockStrategy.callCount == 2, "Second comparison should have been requested")
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 50)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 70)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.9)
        #expect(mockPlayer.lastDuration == 2.0)

        session.stop()
    }
}

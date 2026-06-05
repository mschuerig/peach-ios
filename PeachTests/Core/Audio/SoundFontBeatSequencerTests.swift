import Testing
@testable import Peach

@Suite("SoundFontBeatSequencer")
struct SoundFontBeatSequencerTests {

    // MARK: - Test Constants

    private static let sampleRate = SampleRate.standard44100
    private static let tempo = TempoBPM(120)
    private static let channelID = MIDIChannel(1)

    private static var samplesPerBeat: Int64 {
        SoundFontBeatSequencer.samplesPerBeat(tempo: tempo, sampleRate: sampleRate)
    }

    private static var samplesPerSubdivision: Int64 { samplesPerBeat / 4 }

    private static let testPreset = SF2Preset(name: "test", program: 0, bank: SF2Preset.percussionBank)

    /// Generic 4-subdivision test beat with a rest at `restIndex`. Avoids leaking
    /// CRM's `BeatPosition` enum into Core/Audio tests.
    private static func beat(restAt restIndex: Int) -> Beat {
        let subdivisions: [Subdivision] = (0..<4).map { i in
            if i == restIndex { return .rest }
            return .note(velocity: RhythmVelocity.normal, offset: .zero)
        }
        return Beat(subdivisions: subdivisions)
    }

    // MARK: - samplesPerBeat

    @Test("samplesPerBeat computes correct value from tempo and sample rate")
    func samplesPerBeatCalculation() async {
        // At 120 BPM, one beat (quarter) = 60/120 = 0.5 seconds
        // At 44100 Hz, that's 44100 * 0.5 = 22050
        let result = SoundFontBeatSequencer.samplesPerBeat(
            tempo: TempoBPM(120),
            sampleRate: .standard44100
        )
        #expect(result == 22050)
    }

    // MARK: - buildBatch

    @Test("batch calls beatProvider once per beat")
    func batchCallsProviderPerBeat() async {
        let engine = MockSequencerEngine()
        engine.sampleRate = Self.sampleRate
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        sequencer.configureTiming(tempo: Self.tempo)

        let provider = MockBeatProvider(beats: [Self.beat(restAt: 1), Self.beat(restAt: 2), Self.beat(restAt: 3)])
        let beatCount = 6

        let batch = sequencer.buildBatch(beatCount: beatCount, beatProvider: provider)

        #expect(provider.nextBeatCallCount == beatCount)
        #expect(batch.beats.count == beatCount)
    }

    @Test("batch with one rest per beat produces 3 note-on events per beat")
    func batchProducesExpectedNoteCount() async {
        let engine = MockSequencerEngine()
        engine.sampleRate = Self.sampleRate
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        sequencer.configureTiming(tempo: Self.tempo)

        let provider = MockBeatProvider(beats: (0..<4).map { Self.beat(restAt: $0) })
        let samplesPerBeat = Self.samplesPerBeat

        let batch = sequencer.buildBatch(beatCount: 4, beatProvider: provider)
        let noteOnStatus = SoundFontEngine.noteOnBase | Self.channelID.rawValue

        for beatIndex in 0..<4 {
            let beatStart = Int64(beatIndex) * samplesPerBeat
            let beatEnd = beatStart + samplesPerBeat
            let beatNoteOns = batch.events.filter {
                $0.midiStatus == noteOnStatus
                    && $0.sampleOffset >= beatStart
                    && $0.sampleOffset < beatEnd
            }
            #expect(beatNoteOns.count == 3)
        }
    }

    @Test("batch events within a beat are sorted by sample offset")
    func batchEventsAreOrderedWithinBeat() async {
        let engine = MockSequencerEngine()
        engine.sampleRate = Self.sampleRate
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        sequencer.configureTiming(tempo: Self.tempo)

        let provider = MockBeatProvider(beats: [Self.beat(restAt: 2)])

        let batch = sequencer.buildBatch(beatCount: 3, beatProvider: provider)
        let samplesPerBeat = Self.samplesPerBeat

        for beatIndex in 0..<3 {
            let beatStart = Int64(beatIndex) * samplesPerBeat
            let beatEnd = beatStart + samplesPerBeat
            let beatEvents = batch.events.filter {
                $0.sampleOffset >= beatStart && $0.sampleOffset < beatEnd
            }
            let offsets = beatEvents.map(\.sampleOffset)
            #expect(offsets == offsets.sorted())
        }
    }

    // MARK: - Schedule-buffer overflow regression (caught by TOD pattern_sextuplet_01 trial)

    /// Catalog-wide invariant: a full batch (`beatsPerBatch` repetitions of any
    /// shipping TOD pattern) must fit inside the engine's `scheduleCapacity`
    /// circular buffer. Regression for the Story 84.4 visual-test crash where
    /// `pattern_sextuplet_01` (sextuplet) emitted 6 audibles × 2 events × 500 beats =
    /// 6000 events against a 4096-event buffer, tripping
    /// `SoundFontEngine.scheduleEvents`'s `assertionFailure` on trial start.
    @Test("buildBatch(beatCount: beatsPerBatch) for every TOD catalog pattern fits inside the engine's scheduleCapacity")
    func buildBatchStaysWithinScheduleCapacity() async {
        let engine = MockSequencerEngine()
        engine.sampleRate = Self.sampleRate
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        sequencer.configureTiming(tempo: Self.tempo)

        for pattern in TimingOffsetDetectionPatternCatalog.all {
            // Worst case: every beat carries an offset on the default pickable
            // position — same Beat shape as a real trial.
            let beat = pattern.beat(
                offsetNotePosition: pattern.defaultOffsetNotePosition,
                offsetAmount: .zero
            )
            let provider = MockBeatProvider(beats: [beat])

            let batch = sequencer.buildBatch(
                beatCount: SoundFontBeatSequencer.beatsPerBatch,
                beatProvider: provider
            )

            #expect(
                batch.events.count <= SoundFontEngine.scheduleCapacity,
                "Pattern \(pattern.id) over \(SoundFontBeatSequencer.beatsPerBatch) beats emitted \(batch.events.count) events — exceeds SoundFontEngine.scheduleCapacity \(SoundFontEngine.scheduleCapacity)"
            )
        }
    }

    // MARK: - Lifecycle (start / stop / restart)

    @Test("start sets currentBeat from audio position")
    func startSetsCurrentBeat() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockBeatProvider(beats: [Self.beat(restAt: 1)])

        try await sequencer.start(tempo: Self.tempo, beatProvider: provider)
        try await Task.sleep(for: .milliseconds(20))

        #expect(sequencer.currentBeat != nil)

        try await sequencer.stop()
    }

    @Test("stop resets currentBeat to nil")
    func stopResetsState() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockBeatProvider(beats: [Self.beat(restAt: 1)])

        try await sequencer.start(tempo: Self.tempo, beatProvider: provider)
        try await Task.sleep(for: .milliseconds(20))
        try await sequencer.stop()

        #expect(sequencer.currentBeat == nil)
    }

    @Test("stop clears engine schedule and stops notes")
    func stopClearsEngine() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockBeatProvider(beats: [Self.beat(restAt: 1)])

        try await sequencer.start(tempo: Self.tempo, beatProvider: provider)
        try await Task.sleep(for: .milliseconds(20))
        try await sequencer.stop()

        #expect(engine.clearScheduleCallCount > 0)
        #expect(engine.stopNotesCallCount > 0)
    }

    @Test("restart after stop works correctly")
    func restartAfterStop() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockBeatProvider(beats: [Self.beat(restAt: 2)])

        try await sequencer.start(tempo: Self.tempo, beatProvider: provider)
        try await Task.sleep(for: .milliseconds(20))
        try await sequencer.stop()

        try await sequencer.start(tempo: Self.tempo, beatProvider: provider)
        try await Task.sleep(for: .milliseconds(20))

        #expect(sequencer.currentBeat != nil)
        #expect(engine.scheduleCallCount >= 2)

        try await sequencer.stop()
    }

    @Test("currentBeat reflects the beat at the current sample position")
    func currentBeatTracksPosition() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        let beatA = Self.beat(restAt: 0)
        let beatB = Self.beat(restAt: 2)
        let provider = MockBeatProvider(beats: [beatA, beatB])

        try await sequencer.start(tempo: Self.tempo, beatProvider: provider)
        try await Task.sleep(for: .milliseconds(20))

        let firstSubdivisions = sequencer.currentBeat?.subdivisions
        #expect(firstSubdivisions?.count == 4)

        engine.currentSamplePosition = Self.samplesPerBeat
        try await Task.sleep(for: .milliseconds(20))

        let secondSubdivisions = sequencer.currentBeat?.subdivisions
        #expect(secondSubdivisions?.count == 4)
        if let subs = secondSubdivisions, case .rest = subs[2] {
            // passed
        } else {
            Issue.record("expected .rest at subdivision[2] of beat B")
        }

        try await sequencer.stop()
    }

    // MARK: - playImmediateNote

    @Test("playImmediateNote sends immediate note-on with correct note and velocity")
    func playImmediateNoteSendsNoteOn() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        try sequencer.playImmediateNote(velocity: RhythmVelocity.normal)

        #expect(engine.immediateNoteOnCallCount == 1)
        #expect(engine.lastImmediateNoteOnNote == 76)
        #expect(engine.lastImmediateNoteOnVelocity == RhythmVelocity.normal.rawValue)
    }

    @Test("playImmediateNote does not disturb the schedule buffer")
    func playImmediateNoteDoesNotDisturbSchedule() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        let existingEvents = [ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 76, velocity: 100)]
        engine.scheduleEvents(existingEvents)
        let scheduleCountBefore = engine.scheduleCallCount

        try sequencer.playImmediateNote(velocity: RhythmVelocity.normal)

        #expect(engine.scheduleCallCount == scheduleCountBefore)
        #expect(engine.scheduledEvents.count == existingEvents.count)
    }

    @Test("playImmediateNote sends note-off synchronously via render-thread path")
    func playImmediateNoteSendsNoteOff() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        try sequencer.playImmediateNote(velocity: RhythmVelocity.normal)

        #expect(engine.immediateNoteOffCallCount == 1)
    }

    @Test("rapid playImmediateNote sends note-on and note-off for each tap")
    func rapidPlayImmediateNoteSendsAllEvents() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        try sequencer.playImmediateNote(velocity: RhythmVelocity.normal)
        try sequencer.playImmediateNote(velocity: RhythmVelocity.accent)

        #expect(engine.immediateNoteOnCallCount == 2)
        #expect(engine.immediateNoteOffCallCount == 2)
    }

    @Test("start calls engine setup methods")
    func startCallsEngineSetup() async throws {
        let engine = MockSequencerEngine()
        let sequencer = SoundFontBeatSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockBeatProvider(beats: [Self.beat(restAt: 1)])

        try await sequencer.start(tempo: Self.tempo, beatProvider: provider)

        #expect(engine.ensureAudioSessionConfiguredCallCount == 1)
        #expect(engine.ensureEngineRunningCallCount == 1)
        #expect(engine.loadPresetCallCount == 1)
        #expect(engine.scheduleCallCount == 1)

        try await sequencer.stop()
    }
}

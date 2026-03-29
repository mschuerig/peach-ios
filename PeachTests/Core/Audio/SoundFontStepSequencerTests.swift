import Testing
@testable import Peach

@Suite("SoundFontStepSequencer")
struct SoundFontStepSequencerTests {

    // MARK: - Test Constants

    private static let sampleRate = SampleRate.standard44100
    private static let tempo = TempoBPM(120)
    private static let channelID = SoundFontEngine.ChannelID(1)

    private static var samplesPerStep: Int64 {
        SoundFontStepSequencer.samplesPerStep(tempo: tempo, sampleRate: sampleRate)
    }

    private static var noteOffDelay: Int64 {
        SoundFontStepSequencer.noteOffDelaySamples(
            sampleRate: sampleRate,
            samplesPerStep: samplesPerStep
        )
    }

    // MARK: - samplesPerStep

    @Test("samplesPerStep computes correct value from tempo and sample rate")
    func samplesPerStepCalculation() async {
        // At 120 BPM, one sixteenth = 60/(120*4) = 0.125 seconds
        // At 44100 Hz, that's 44100 * 0.125 = 5512.5 → truncated to 5512
        let result = SoundFontStepSequencer.samplesPerStep(
            tempo: TempoBPM(120),
            sampleRate: .standard44100
        )
        #expect(result == 5512)
    }

    // MARK: - buildCycleEvents

    @Test("cycle with gap at second position produces 3 note-on and 3 note-off events")
    func cycleEventsGapAtSecond() async {
        let cycle = CycleDefinition(gapPosition: .second)
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: 0,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let noteOns = events.filter { $0.midiStatus == SoundFontEngine.noteOnBase | Self.channelID.rawValue }
        let noteOffs = events.filter { $0.midiStatus == SoundFontEngine.noteOffBase | Self.channelID.rawValue }

        #expect(noteOns.count == 3)
        #expect(noteOffs.count == 3)
    }

    @Test("gap position produces no events at that step's sample offset")
    func gapPositionIsSilent() async {
        let gapPosition = StepPosition.third
        let cycle = CycleDefinition(gapPosition: gapPosition)
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: 0,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let gapOffset = Int64(gapPosition.rawValue) * Self.samplesPerStep
        let eventsAtGap = events.filter { $0.sampleOffset == gapOffset }
        #expect(eventsAtGap.isEmpty)
    }

    @Test("step 1 uses accent velocity 127")
    func firstStepUsesAccentVelocity() async {
        let cycle = CycleDefinition(gapPosition: .second)
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: 0,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let firstStepNoteOn = events.first {
            $0.sampleOffset == 0 && $0.midiStatus == SoundFontEngine.noteOnBase | Self.channelID.rawValue
        }
        #expect(firstStepNoteOn?.velocity == StepVelocity.accent.rawValue)
    }

    @Test("non-gap steps 2–4 use normal velocity 100")
    func nonGapStepsUseNormalVelocity() async {
        let cycle = CycleDefinition(gapPosition: .first) // gap at first, so steps 2-4 are normal
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: 0,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let noteOns = events.filter {
            $0.midiStatus == SoundFontEngine.noteOnBase | Self.channelID.rawValue
        }

        // All 3 non-gap steps should have normal velocity (first is the gap)
        for noteOn in noteOns {
            #expect(noteOn.velocity == StepVelocity.normal.rawValue)
        }
    }

    @Test("step 1 uses accent even when gap is elsewhere")
    func step1AccentWhenGapElsewhere() async {
        for gap in [StepPosition.second, .third, .fourth] {
            let cycle = CycleDefinition(gapPosition: gap)
            let events = SoundFontStepSequencer.buildCycleEvents(
                cycle: cycle,
                cycleOffset: 0,
                samplesPerStep: Self.samplesPerStep,
                noteOffDelaySamples: Self.noteOffDelay,
                channelID: Self.channelID
            )

            let firstStepNoteOn = events.first {
                $0.sampleOffset == 0 && $0.midiStatus == SoundFontEngine.noteOnBase | Self.channelID.rawValue
            }
            #expect(firstStepNoteOn?.velocity == StepVelocity.accent.rawValue)
        }
    }

    @Test("when gap is at first position, no accent event is produced")
    func noAccentWhenGapAtFirst() async {
        let cycle = CycleDefinition(gapPosition: .first)
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: 0,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let accentEvents = events.filter { $0.velocity == StepVelocity.accent.rawValue }
        #expect(accentEvents.isEmpty)
    }

    @Test("events use correct MIDI note 76")
    func eventsUseClickNote() async {
        let cycle = CycleDefinition(gapPosition: .second)
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: 0,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        for event in events {
            #expect(event.midiNote == 76)
        }
    }

    @Test("note-off events follow note-on events by the correct delay")
    func noteOffTimingIsCorrect() async {
        let cycle = CycleDefinition(gapPosition: .fourth)
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: 0,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let channelRaw = Self.channelID.rawValue
        let noteOns = events.filter { $0.midiStatus == SoundFontEngine.noteOnBase | channelRaw }
        let noteOffs = events.filter { $0.midiStatus == SoundFontEngine.noteOffBase | channelRaw }

        #expect(noteOns.count == noteOffs.count)
        for (on, off) in zip(
            noteOns.sorted { $0.sampleOffset < $1.sampleOffset },
            noteOffs.sorted { $0.sampleOffset < $1.sampleOffset }
        ) {
            #expect(off.sampleOffset - on.sampleOffset == Self.noteOffDelay)
        }
    }

    @Test("cycle offset shifts all event sample offsets")
    func cycleOffsetShiftsEvents() async {
        let cycleOffset: Int64 = 100_000
        let cycle = CycleDefinition(gapPosition: .second)
        let events = SoundFontStepSequencer.buildCycleEvents(
            cycle: cycle,
            cycleOffset: cycleOffset,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        for event in events {
            #expect(event.sampleOffset >= cycleOffset)
        }
    }

    // MARK: - buildBatch

    @Test("batch events call stepProvider once per cycle")
    func batchCallsProviderPerCycle() async {
        let provider = MockStepProvider(gapPositions: [.second, .third, .fourth])
        let cycleCount = 6

        let batch = SoundFontStepSequencer.buildBatch(
            cycleCount: cycleCount,
            stepProvider: provider,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        #expect(provider.nextCycleCallCount == cycleCount)
        #expect(batch.definitions.count == cycleCount)
    }

    @Test("batch events with changing gap positions produces correct events per cycle")
    func batchWithChangingGaps() async {
        let gaps: [StepPosition] = [.first, .second, .third, .fourth]
        let provider = MockStepProvider(gapPositions: gaps)
        let samplesPerCycle = Self.samplesPerStep * 4

        let batch = SoundFontStepSequencer.buildBatch(
            cycleCount: 4,
            stepProvider: provider,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let channelRaw = Self.channelID.rawValue

        // Each cycle should have 3 note-on events (4 steps minus 1 gap)
        for cycleIndex in 0..<4 {
            let cycleStart = Int64(cycleIndex) * samplesPerCycle
            let cycleEnd = cycleStart + samplesPerCycle

            let cycleNoteOns = batch.events.filter {
                $0.midiStatus == SoundFontEngine.noteOnBase | channelRaw
                    && $0.sampleOffset >= cycleStart
                    && $0.sampleOffset < cycleEnd
            }
            #expect(cycleNoteOns.count == 3)
        }
    }

    @Test("batch events are ordered by sample offset within each cycle")
    func batchEventsAreOrdered() async {
        let provider = MockStepProvider(gapPositions: [.third])

        let batch = SoundFontStepSequencer.buildBatch(
            cycleCount: 3,
            stepProvider: provider,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        // Verify events within each cycle are non-decreasing in offset
        let samplesPerCycle = Self.samplesPerStep * 4
        for cycleIndex in 0..<3 {
            let cycleStart = Int64(cycleIndex) * samplesPerCycle
            let cycleEnd = cycleStart + samplesPerCycle
            let cycleEvents = batch.events.filter {
                $0.sampleOffset >= cycleStart && $0.sampleOffset < cycleEnd
            }
            let offsets = cycleEvents.map(\.sampleOffset)
            #expect(offsets == offsets.sorted())
        }
    }

    @Test("batch definitions track the gap positions provided by stepProvider")
    func batchDefinitionsMatchProvider() async {
        let gaps: [StepPosition] = [.first, .third, .second, .fourth, .second]
        let provider = MockStepProvider(gapPositions: gaps)

        let batch = SoundFontStepSequencer.buildBatch(
            cycleCount: 5,
            stepProvider: provider,
            samplesPerStep: Self.samplesPerStep,
            noteOffDelaySamples: Self.noteOffDelay,
            channelID: Self.channelID
        )

        let expectedGaps = gaps
        let actualGaps = batch.definitions.map(\.gapPosition)
        #expect(actualGaps == expectedGaps)
    }

    @Test("each gap position produces exactly one silent step per cycle")
    func eachGapPositionHasOneSilentStep() async {
        for gap in StepPosition.allCases {
            let provider = MockStepProvider(gapPositions: [gap])
            let batch = SoundFontStepSequencer.buildBatch(
                cycleCount: 1,
                stepProvider: provider,
                samplesPerStep: Self.samplesPerStep,
                noteOffDelaySamples: Self.noteOffDelay,
                channelID: Self.channelID
            )

            let channelRaw = Self.channelID.rawValue
            let noteOns = batch.events.filter {
                $0.midiStatus == SoundFontEngine.noteOnBase | channelRaw
            }
            // 4 steps minus 1 gap = 3 note-on events
            #expect(noteOns.count == 3)

            // Verify the gap step has no event
            let gapOffset = Int64(gap.rawValue) * Self.samplesPerStep
            let eventsAtGap = batch.events.filter { $0.sampleOffset == gapOffset }
            #expect(eventsAtGap.isEmpty)
        }
    }

    // MARK: - noteOffDelaySamples

    @Test("note-off delay is capped to not exceed step duration")
    func noteOffDelayIsCapped() async {
        // Very fast tempo where step duration < 50ms
        let fastTempo = TempoBPM(240)
        let fastSamplesPerStep = SoundFontStepSequencer.samplesPerStep(
            tempo: fastTempo,
            sampleRate: Self.sampleRate
        )
        let delay = SoundFontStepSequencer.noteOffDelaySamples(
            sampleRate: Self.sampleRate,
            samplesPerStep: fastSamplesPerStep
        )

        #expect(delay < fastSamplesPerStep)
    }

    // MARK: - Lifecycle (start / stop / restart)

    private static let testPreset = SF2Preset(name: "test", program: 0, bank: SF2Preset.percussionBank)

    @Test("start sets currentStep and currentCycle from audio position")
    func startSetsObservableState() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockStepProvider(gapPositions: [.second])

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)
        try await Task.sleep(for: .milliseconds(20))

        #expect(sequencer.currentStep != nil)
        #expect(sequencer.currentCycle != nil)

        try await sequencer.stop()
    }

    @Test("stop resets currentStep and currentCycle to nil")
    func stopResetsState() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockStepProvider(gapPositions: [.second])

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)
        try await Task.sleep(for: .milliseconds(20))
        try await sequencer.stop()

        #expect(sequencer.currentStep == nil)
        #expect(sequencer.currentCycle == nil)
    }

    @Test("stop clears engine schedule and stops notes")
    func stopClearsEngine() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockStepProvider(gapPositions: [.second])

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)
        try await Task.sleep(for: .milliseconds(20))
        try await sequencer.stop()

        #expect(engine.clearScheduleCallCount > 0)
        #expect(engine.stopNotesCallCount > 0)
    }

    @Test("restart after stop works correctly")
    func restartAfterStop() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockStepProvider(gapPositions: [.third])

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)
        try await Task.sleep(for: .milliseconds(20))
        try await sequencer.stop()

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)
        try await Task.sleep(for: .milliseconds(20))

        #expect(sequencer.currentStep != nil)
        #expect(engine.scheduleCallCount >= 2)

        try await sequencer.stop()
    }

    @Test("currentStep tracks actual audio position")
    func currentStepTracksAudioPosition() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockStepProvider(gapPositions: [.second])

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)
        try await Task.sleep(for: .milliseconds(20))

        // Position 0 → first step
        #expect(sequencer.currentStep == .first)

        // Advance to second step
        engine.currentSamplePosition = Self.samplesPerStep
        try await Task.sleep(for: .milliseconds(20))
        #expect(sequencer.currentStep == .second)

        // Advance to fourth step
        engine.currentSamplePosition = Self.samplesPerStep * 3
        try await Task.sleep(for: .milliseconds(20))
        #expect(sequencer.currentStep == .fourth)

        try await sequencer.stop()
    }

    @Test("currentCycle reflects the correct cycle definition at each position")
    func currentCycleTracksPosition() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockStepProvider(gapPositions: [.first, .third])

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)
        try await Task.sleep(for: .milliseconds(20))

        // Cycle 0 → gap at .first
        #expect(sequencer.currentCycle?.gapPosition == .first)

        // Advance to cycle 1 → gap at .third
        let samplesPerCycle = Self.samplesPerStep * 4
        engine.currentSamplePosition = samplesPerCycle
        try await Task.sleep(for: .milliseconds(20))
        #expect(sequencer.currentCycle?.gapPosition == .third)

        try await sequencer.stop()
    }

    // MARK: - playImmediateNote

    @Test("playImmediateNote sends immediate note-on with correct note and velocity")
    func playImmediateNoteSendsNoteOn() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        try sequencer.playImmediateNote(velocity: StepVelocity.normal)

        #expect(engine.immediateNoteOnCallCount == 1)
        #expect(engine.lastImmediateNoteOnNote == 76)
        #expect(engine.lastImmediateNoteOnVelocity == StepVelocity.normal.rawValue)
    }

@Test("playImmediateNote does not disturb the schedule buffer")
    func playImmediateNoteDoesNotDisturbSchedule() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        // Pre-populate a schedule
        let existingEvents = [ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 76, velocity: 100)]
        engine.scheduleEvents(existingEvents)
        let scheduleCountBefore = engine.scheduleCallCount

        try sequencer.playImmediateNote(velocity: StepVelocity.normal)

        // scheduleEvents should NOT have been called again
        #expect(engine.scheduleCallCount == scheduleCountBefore)
        #expect(engine.scheduledEvents.count == existingEvents.count)
    }

    @Test("playImmediateNote sends note-off synchronously via render-thread path")
    func playImmediateNoteSendsNoteOff() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        try sequencer.playImmediateNote(velocity: StepVelocity.normal)

        #expect(engine.immediateNoteOffCallCount == 1)
    }

    @Test("rapid playImmediateNote sends note-on and note-off for each tap")
    func rapidPlayImmediateNoteSendsAllEvents() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)

        try sequencer.playImmediateNote(velocity: StepVelocity.normal)
        try sequencer.playImmediateNote(velocity: StepVelocity.accent)

        #expect(engine.immediateNoteOnCallCount == 2)
        #expect(engine.immediateNoteOffCallCount == 2)
    }

    @Test("start calls engine setup methods")
    func startCallsEngineSetup() async throws {
        let engine = MockStepSequencerEngine()
        let sequencer = SoundFontStepSequencer(engine: engine, preset: Self.testPreset, channel: Self.channelID)
        let provider = MockStepProvider(gapPositions: [.second])

        try await sequencer.start(tempo: Self.tempo, stepProvider: provider)

        #expect(engine.ensureAudioSessionConfiguredCallCount == 1)
        #expect(engine.ensureEngineRunningCallCount == 1)
        #expect(engine.loadPresetCallCount == 1)
        #expect(engine.scheduleCallCount == 1)

        try await sequencer.stop()
    }
}

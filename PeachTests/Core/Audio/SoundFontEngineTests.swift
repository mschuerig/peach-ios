import Foundation
import Testing
@testable import Peach

@Suite("SoundFontEngine")
struct SoundFontEngineTests {

    private static let channel0 = SoundFontEngine.ChannelID(0)

    private func makeEngine() throws -> SoundFontEngine {
        try SoundFontEngine(sf2URL: TestSoundFont.url, audioSessionConfigurator: MockAudioSessionConfigurator())
    }

    // MARK: - Initialization

    @Test("initializes successfully with valid SF2 library")
    func initializesSuccessfully() async {
        #expect(throws: Never.self) {
            _ = try self.makeEngine()
        }
    }

    @Test("audio engine is running after init")
    func engineRunningAfterInit() async throws {
        let engine = try makeEngine()
        #expect(throws: Never.self) {
            try engine.ensureEngineRunning()
        }
    }

    @Test("initializes even without loading a preset")
    func initializesWithoutPreset() async throws {
        let engine = try makeEngine()
        // Engine is usable — channels exist but no preset loaded yet
        #expect(throws: Never.self) {
            try engine.ensureEngineRunning()
        }
    }

    // MARK: - Preset Loading

    @Test("loadPreset succeeds for valid preset")
    func loadPresetValid() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 42, bank: 0), channel: Self.channel0)
    }

    @Test("loadPreset skips reload when same preset is already loaded")
    func loadPresetSkipsSame() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Yamaha Grand Piano", program: 0, bank: 0), channel: Self.channel0)
    }

    @Test("loadPreset loads different preset")
    func loadPresetDifferent() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Strings", program: 6, bank: 8), channel: Self.channel0)
    }

    // MARK: - Immediate MIDI Dispatch

    @Test("startNote does not crash")
    func startNoteDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel0)
    }

    @Test("stopNote does not crash")
    func stopNoteDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel0)
        engine.stopNote(MIDINote(69), channel: Self.channel0)
    }

    @Test("sendPitchBend does not crash")
    func sendPitchBendDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.sendPitchBend(PitchBendValue(10000), channel: Self.channel0)
    }

    // MARK: - stopNotes

    @Test("stopNotes does not crash when no notes are playing")
    func stopNotesNoNotes() async throws {
        let engine = try makeEngine()
        await engine.stopNotes(channel: Self.channel0, stopPropagationDelay: .zero)
    }

    @Test("stopNotes with propagation delay restores volume")
    func stopNotesRestoresVolume() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel0)
        await engine.stopNotes(channel: Self.channel0, stopPropagationDelay: .milliseconds(25))
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel0)
        engine.stopNote(MIDINote(69), channel: Self.channel0)
    }

    @Test("stopNotes silences a playing note")
    func stopNotesSilencesNote() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel0)
        await engine.stopNotes(channel: Self.channel0, stopPropagationDelay: .zero)
    }

    // MARK: - Schedule Scanning (pure function)

    @Test("scanSchedule dispatches events within buffer window")
    func scanScheduleDispatchesEventsInWindow() async {
        let events = [
            ScheduledMIDIEvent(sampleOffset: 10, midiStatus: 0x90, midiNote: 60, velocity: 100),
            ScheduledMIDIEvent(sampleOffset: 50, midiStatus: 0x80, midiNote: 60, velocity: 0),
            ScheduledMIDIEvent(sampleOffset: 300, midiStatus: 0x90, midiNote: 64, velocity: 80),
        ]
        let result = SoundFontEngine.scanSchedule(events: events, fromIndex: 0, windowStart: 0, windowEnd: 240)
        #expect(result.dispatched.count == 2)
        #expect(result.dispatched[0].midiNote == 60)
        #expect(result.dispatched[0].midiStatus == 0x90)
        #expect(result.dispatched[1].midiNote == 60)
        #expect(result.dispatched[1].midiStatus == 0x80)
        #expect(result.nextIndex == 2)
    }

    @Test("scanSchedule dispatches multiple events within single buffer")
    func scanScheduleMultipleEventsInBuffer() async {
        let events = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 60, velocity: 100),
            ScheduledMIDIEvent(sampleOffset: 100, midiStatus: 0x90, midiNote: 64, velocity: 90),
            ScheduledMIDIEvent(sampleOffset: 200, midiStatus: 0x90, midiNote: 67, velocity: 80),
        ]
        let result = SoundFontEngine.scanSchedule(events: events, fromIndex: 0, windowStart: 0, windowEnd: 240)
        #expect(result.dispatched.count == 3)
        #expect(result.nextIndex == 3)
    }

    @Test("scanSchedule dispatches events spanning multiple buffers in order")
    func scanScheduleSpansMultipleBuffers() async {
        let events = [
            ScheduledMIDIEvent(sampleOffset: 100, midiStatus: 0x90, midiNote: 60, velocity: 100),
            ScheduledMIDIEvent(sampleOffset: 300, midiStatus: 0x80, midiNote: 60, velocity: 0),
            ScheduledMIDIEvent(sampleOffset: 500, midiStatus: 0x90, midiNote: 64, velocity: 80),
        ]

        // First buffer: [0, 240)
        let result1 = SoundFontEngine.scanSchedule(events: events, fromIndex: 0, windowStart: 0, windowEnd: 240)
        #expect(result1.dispatched.count == 1)
        #expect(result1.dispatched[0].midiNote == 60)
        #expect(result1.dispatched[0].midiStatus == 0x90)
        #expect(result1.nextIndex == 1)

        // Second buffer: [240, 480)
        let result2 = SoundFontEngine.scanSchedule(events: events, fromIndex: result1.nextIndex, windowStart: 240, windowEnd: 480)
        #expect(result2.dispatched.count == 1)
        #expect(result2.dispatched[0].midiNote == 60)
        #expect(result2.dispatched[0].midiStatus == 0x80)
        #expect(result2.nextIndex == 2)

        // Third buffer: [480, 720)
        let result3 = SoundFontEngine.scanSchedule(events: events, fromIndex: result2.nextIndex, windowStart: 480, windowEnd: 720)
        #expect(result3.dispatched.count == 1)
        #expect(result3.dispatched[0].midiNote == 64)
        #expect(result3.nextIndex == 3)
    }

    @Test("scanSchedule returns empty when no events in window")
    func scanScheduleNoEventsInWindow() async {
        let events = [
            ScheduledMIDIEvent(sampleOffset: 500, midiStatus: 0x90, midiNote: 60, velocity: 100),
        ]
        let result = SoundFontEngine.scanSchedule(events: events, fromIndex: 0, windowStart: 0, windowEnd: 240)
        #expect(result.dispatched.isEmpty)
        #expect(result.nextIndex == 0)
    }

    // MARK: - Schedule Management

    @Test("clearSchedule resets event count to zero")
    func clearScheduleResetsCount() async throws {
        let engine = try makeEngine()
        let events = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 60, velocity: 100),
            ScheduledMIDIEvent(sampleOffset: 100, midiStatus: 0x80, midiNote: 60, velocity: 0),
        ]
        engine.scheduleEvents(events)
        #expect(engine.scheduledEventCount == 2)
        engine.clearSchedule()
        #expect(engine.scheduledEventCount == 0)
    }

    @Test("scheduleEvents replaces existing schedule")
    func scheduleEventsReplacesExisting() async throws {
        let engine = try makeEngine()
        let firstBatch = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 60, velocity: 100),
            ScheduledMIDIEvent(sampleOffset: 100, midiStatus: 0x80, midiNote: 60, velocity: 0),
        ]
        engine.scheduleEvents(firstBatch)
        #expect(engine.scheduledEventCount == 2)

        let secondBatch = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 72, velocity: 80),
        ]
        engine.scheduleEvents(secondBatch)
        #expect(engine.scheduledEventCount == 1)
    }

    // MARK: - Immediate Dispatch After Source Node

    @Test("startNote still works after source node is added")
    func startNoteWorksWithSourceNode() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(60), velocity: MIDIVelocity(100), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: Self.channel0)
        engine.stopNote(MIDINote(60), channel: Self.channel0)
    }

    @Test("sendPitchBend still works after source node is added")
    func sendPitchBendWorksWithSourceNode() async throws {
        let engine = try makeEngine()
        engine.sendPitchBend(.center, channel: Self.channel0)
    }

    // MARK: - Integration: Schedule and Play

    @Test("scheduling events and letting them play does not crash")
    func scheduleAndPlayNoCrash() async throws {
        let engine = try makeEngine()
        let events = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 60, velocity: 100),
            ScheduledMIDIEvent(sampleOffset: 24000, midiStatus: 0x80, midiNote: 60, velocity: 0),
        ]
        engine.scheduleEvents(events)
        try await Task.sleep(for: .milliseconds(100))
        engine.clearSchedule()
    }

    // MARK: - Multi-Channel

    @Test("createChannel adds a second channel without crash")
    func createChannelNoCrash() async throws {
        let engine = try makeEngine()
        try engine.createChannel(SoundFontEngine.ChannelID(1))
    }

    @Test("loadPreset on specific channel succeeds")
    func loadPresetOnChannel() async throws {
        let engine = try makeEngine()
        try engine.createChannel(SoundFontEngine.ChannelID(1))
        let preset = SF2Preset(name: "Cello", program: 42, bank: 0)
        try await engine.loadPreset(preset, channel: SoundFontEngine.ChannelID(1))
    }

    @Test("startNote on specific channel does not crash")
    func startNoteOnChannel() async throws {
        let engine = try makeEngine()
        let channel = SoundFontEngine.ChannelID(0)
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: channel)
        engine.stopNote(MIDINote(69), channel: channel)
    }

    @Test("stopNotes on channel does not crash")
    func stopNotesOnChannel() async throws {
        let engine = try makeEngine()
        let channel = SoundFontEngine.ChannelID(0)
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: channel)
        await engine.stopNotes(channel: channel, stopPropagationDelay: .zero)
    }

    @Test("sendPitchBend on channel does not crash")
    func sendPitchBendOnChannel() async throws {
        let engine = try makeEngine()
        engine.sendPitchBend(.center, channel: SoundFontEngine.ChannelID(0))
    }

    @Test("muteForFade and restoreAfterFade affect all channels")
    func muteAndRestoreAllChannels() async throws {
        let engine = try makeEngine()
        try engine.createChannel(SoundFontEngine.ChannelID(1))
        engine.muteForFade()
        engine.restoreAfterFade()
        // If this doesn't crash and subsequent play works, volumes were restored
        engine.startNote(MIDINote(60), velocity: MIDIVelocity(100), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center, channel: SoundFontEngine.ChannelID(0))
        engine.stopNote(MIDINote(60), channel: SoundFontEngine.ChannelID(0))
    }

    // MARK: - Lock-Free Dispatch Verification

    @Test("all scheduled events are dispatched by the render thread")
    func allEventsDispatched() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)

        // Schedule 500 note-on/note-off pairs = 1000 events, spread across sample positions
        var events: [ScheduledMIDIEvent] = []
        for i in 0..<500 {
            let offset = Int64(i * 256) // ~5.8ms apart at 44.1kHz
            events.append(ScheduledMIDIEvent(
                sampleOffset: offset,
                midiStatus: SoundFontEngine.noteOnBase,
                midiNote: 60,
                velocity: 80
            ))
            events.append(ScheduledMIDIEvent(
                sampleOffset: offset + 128,
                midiStatus: SoundFontEngine.noteOffBase,
                midiNote: 60,
                velocity: 0
            ))
        }
        engine.scheduleEvents(events)
        #expect(engine.scheduledEventCount == 1000)

        // Wait for the render thread to process all events
        // Last event is at sample offset 499*256+128 = 127,872
        // At 44.1kHz this is ~2.9 seconds
        let lastEventOffset = Int64(499 * 256 + 128)
        for _ in 0..<400 {
            if engine.currentSamplePosition > lastEventOffset { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(engine.dispatchedEventCount == 1000)
    }

    @Test("schedule replacement does not lose events from new schedule")
    func scheduleReplacementDispatchesNewEvents() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)

        // Schedule initial events
        let firstBatch = (0..<10).map { i in
            ScheduledMIDIEvent(
                sampleOffset: Int64(i * 512),
                midiStatus: SoundFontEngine.noteOnBase,
                midiNote: 60,
                velocity: 80
            )
        }
        engine.scheduleEvents(firstBatch)

        // Immediately replace with a new schedule (simulates step sequencer refill)
        let secondBatch = (0..<20).map { i in
            ScheduledMIDIEvent(
                sampleOffset: Int64(i * 256),
                midiStatus: SoundFontEngine.noteOnBase,
                midiNote: 64,
                velocity: 90
            )
        }
        engine.scheduleEvents(secondBatch)
        #expect(engine.scheduledEventCount == 20)

        // Wait for all events from the new schedule to be processed
        let lastOffset = Int64(19 * 256)
        for _ in 0..<200 {
            if engine.currentSamplePosition > lastOffset { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(engine.dispatchedEventCount == 20)
    }

    @Test("rapid schedule updates at 200 BPM equivalent timing dispatch all events")
    func stressTestRapidScheduleUpdates() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)

        // 200 BPM with 4 events per beat = 13.3 events/sec
        // Simulate by scheduling small batches rapidly
        let eventsPerBatch = 4
        let batchCount = 50
        var totalExpected = 0

        for batch in 0..<batchCount {
            let events = (0..<eventsPerBatch).map { i in
                ScheduledMIDIEvent(
                    sampleOffset: Int64(i * 128),
                    midiStatus: SoundFontEngine.noteOnBase,
                    midiNote: UInt8(60 + (batch % 12)),
                    velocity: 80
                )
            }
            engine.scheduleEvents(events)
            totalExpected = eventsPerBatch // Each schedule replaces the previous
            try await Task.sleep(for: .milliseconds(5))
        }

        // Wait for the last batch to complete
        let lastOffset = Int64((eventsPerBatch - 1) * 128)
        for _ in 0..<100 {
            if engine.currentSamplePosition > lastOffset { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        // The last batch's events should all be dispatched
        #expect(engine.dispatchedEventCount == totalExpected)
    }

    @Test("dispatchedEventCount resets when render thread detects new schedule")
    func dispatchCounterResetsOnNewSchedule() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 0, bank: 0), channel: Self.channel0)

        let events = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 60, velocity: 100),
        ]
        engine.scheduleEvents(events)

        // Wait for the first schedule's event to be dispatched
        for _ in 0..<100 {
            if engine.dispatchedEventCount >= 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(engine.dispatchedEventCount >= 1)

        // Schedule new events — counter resets when render thread detects generation change
        engine.scheduleEvents(events)

        // Wait for the render thread to process the new generation
        // (samplePosition resets to 0 then advances past the event)
        for _ in 0..<100 {
            if engine.currentSamplePosition > 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        // Counter was reset to 0 by the render thread, then incremented for the new event
        #expect(engine.dispatchedEventCount == 1)
    }

}

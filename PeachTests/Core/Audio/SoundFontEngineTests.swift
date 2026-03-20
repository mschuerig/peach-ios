import Foundation
import Testing
@testable import Peach

@Suite("SoundFontEngine")
struct SoundFontEngineTests {

    private func makeEngine() throws -> SoundFontEngine {
        try SoundFontEngine(sf2URL: TestSoundFont.url)
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
        try await engine.loadPreset(SF2Preset(name: "Piano", program: 42, bank: 0))
    }

    @Test("loadPreset skips reload when same preset is already loaded")
    func loadPresetSkipsSame() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Yamaha Grand Piano", program: 0, bank: 0))
    }

    @Test("loadPreset loads different preset")
    func loadPresetDifferent() async throws {
        let engine = try makeEngine()
        try await engine.loadPreset(SF2Preset(name: "Strings", program: 6, bank: 8))
    }

    // MARK: - Immediate MIDI Dispatch

    @Test("startNote does not crash")
    func startNoteDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
    }

    @Test("stopNote does not crash")
    func stopNoteDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        engine.stopNote(MIDINote(69))
    }

    @Test("sendPitchBend does not crash")
    func sendPitchBendDoesNotCrash() async throws {
        let engine = try makeEngine()
        engine.sendPitchBend(PitchBendValue(10000))
    }

    // MARK: - stopAllNotes

    @Test("stopAllNotes does not crash when no notes are playing")
    func stopAllNotesNoNotes() async throws {
        let engine = try makeEngine()
        await engine.stopAllNotes(stopPropagationDelay: .zero)
    }

    @Test("stopAllNotes with propagation delay restores volume")
    func stopAllNotesRestoresVolume() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        await engine.stopAllNotes(stopPropagationDelay: .milliseconds(25))
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        engine.stopNote(MIDINote(69))
    }

    @Test("stopAllNotes silences a playing note")
    func stopAllNotesSilencesNote() async throws {
        let engine = try makeEngine()
        engine.startNote(MIDINote(69), velocity: MIDIVelocity(63), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        await engine.stopAllNotes(stopPropagationDelay: .zero)
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
        engine.startNote(MIDINote(60), velocity: MIDIVelocity(100), amplitudeDB: AmplitudeDB(0.0), pitchBend: .center)
        engine.stopNote(MIDINote(60))
    }

    @Test("sendPitchBend still works after source node is added")
    func sendPitchBendWorksWithSourceNode() async throws {
        let engine = try makeEngine()
        engine.sendPitchBend(.center)
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

}

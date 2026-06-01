import Foundation
import os

// MARK: - SequencerEngine

protocol SequencerEngine {
    var sampleRate: SampleRate { get }
    var currentSamplePosition: Int64 { get }
    func ensureAudioSessionConfigured() throws
    func ensureEngineRunning() throws
    func loadPreset(_ preset: SF2Preset, channel: MIDIChannel) async throws
    func scheduleEvents(_ events: [ScheduledMIDIEvent])
    func clearSchedule()
    func stopNotes(channel: MIDIChannel, fadeOutDuration: Duration) async
    func immediateNoteOn(channel: MIDIChannel, note: UInt8, velocity: UInt8)
    func immediateNoteOff(channel: MIDIChannel, note: UInt8, delaySamples: Int64)
    func samplePosition(forHostTime hostTime: UInt64) -> Int64
}

extension SoundFontEngine: SequencerEngine {}

// MARK: - SoundFontBeatSequencer

@Observable
final class SoundFontBeatSequencer: BeatSequencer {

    // MARK: - Constants

    private nonisolated static let clickNote = MIDINote(76)
    private nonisolated static let noteOffDuration: Duration = .milliseconds(50)

    /// Number of beats to schedule in each batch. At 60 BPM each beat is 1 second,
    /// so 500 beats ≈ 8+ minutes of audio. The engine's 4096-event buffer accommodates
    /// up to ~8 events per beat at this batch size, which fits every shipping
    /// discipline (CRM = 6 events/beat, TOD = 8 events/beat). Disciplines emitting
    /// denser beats must lower this constant.
    private nonisolated static let beatsPerBatch = 500

    /// Polling interval for sample-position-driven UI tracking (~120 Hz).
    private nonisolated static let uiPollingInterval: Duration = .milliseconds(8)

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontBeatSequencer")

    // MARK: - Dependencies

    private let engine: any SequencerEngine
    private let channel: MIDIChannel
    private let preset: SF2Preset

    // MARK: - Observable State

    private(set) var currentBeat: Beat?

    // MARK: - Timing State

    private(set) var samplesPerBeat: Int64 = 0

    var timing: SequencerTiming {
        SequencerTiming(
            samplePosition: engine.currentSamplePosition,
            samplesPerBeat: samplesPerBeat,
            sampleRate: engine.sampleRate
        )
    }

    // MARK: - State

    private var runLoopTask: Task<Void, any Error>?

    // MARK: - Initialization

    init(engine: any SequencerEngine, preset: SF2Preset, channel: MIDIChannel) {
        self.engine = engine
        self.preset = preset
        self.channel = channel
    }

    // MARK: - BeatSequencer Protocol

    func start(tempo: TempoBPM, beatProvider: any BeatProvider) async throws {
        try await stop()

        try engine.ensureAudioSessionConfigured()
        try engine.ensureEngineRunning()
        try await engine.loadPreset(preset, channel: channel)

        configureTiming(tempo: tempo)

        let batch = buildBatch(
            beatCount: Self.beatsPerBatch,
            beatProvider: beatProvider
        )
        engine.scheduleEvents(batch.events)

        logger.info("Beat sequencer started at \(tempo.value) BPM")

        let refillThreshold = Int64(Self.beatsPerBatch - 10) * samplesPerBeat

        runLoopTask = Task {
            var beats = batch.beats
            var lastBeatModIndex = -1

            while !Task.isCancelled {
                let position = engine.currentSamplePosition

                let modIndex = Int(position / samplesPerBeat) % beats.count
                if modIndex != lastBeatModIndex {
                    currentBeat = beats[modIndex]
                    lastBeatModIndex = modIndex
                }

                if position >= refillThreshold {
                    let nextBatch = buildBatch(
                        beatCount: Self.beatsPerBatch,
                        beatProvider: beatProvider
                    )
                    beats = nextBatch.beats
                    lastBeatModIndex = -1
                    engine.scheduleEvents(nextBatch.events)
                }

                try await Task.sleep(for: Self.uiPollingInterval)
            }
        }
    }

    func playImmediateNote(velocity: MIDIVelocity) throws {
        let midiNoteRaw = UInt8(Self.clickNote.rawValue)
        let noteOffSamples = engine.sampleRate.samples(for: Self.noteOffDuration)

        engine.immediateNoteOn(channel: channel, note: midiNoteRaw, velocity: velocity.rawValue)
        engine.immediateNoteOff(channel: channel, note: midiNoteRaw, delaySamples: noteOffSamples)
    }

    func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
        engine.samplePosition(forHostTime: hostTime)
    }

    func stop() async throws {
        runLoopTask?.cancel()
        _ = await runLoopTask?.result
        runLoopTask = nil
        currentBeat = nil
        samplesPerBeat = 0
        engine.clearSchedule()
        await engine.stopNotes(channel: channel, fadeOutDuration: .zero)
        logger.info("Beat sequencer stopped")
    }

    // MARK: - Timing Configuration (internal for testability)

    func configureTiming(tempo: TempoBPM) {
        samplesPerBeat = Self.samplesPerBeat(tempo: tempo, sampleRate: engine.sampleRate)
    }

    // MARK: - Event Building (pure, testable)

    static func samplesPerBeat(tempo: TempoBPM, sampleRate: SampleRate) -> Int64 {
        sampleRate.samples(for: tempo.quarterNoteDuration)
    }

    struct Batch {
        let events: [ScheduledMIDIEvent]
        let beats: [Beat]
    }

    func buildBatch(
        beatCount: Int,
        beatProvider: any BeatProvider
    ) -> Batch {
        var allEvents: [ScheduledMIDIEvent] = []
        allEvents.reserveCapacity(beatCount * 6)
        var beats: [Beat] = []
        beats.reserveCapacity(beatCount)

        let sampleRate = engine.sampleRate
        let noteOffDelay = sampleRate.samples(for: Self.noteOffDuration)

        for beatIndex in 0..<beatCount {
            let beat = beatProvider.nextBeat()
            beats.append(beat)
            let beatOffset = Int64(beatIndex) * samplesPerBeat

            let beatEvents = beat.events(
                beatOffset: beatOffset,
                beatDuration: samplesPerBeat,
                sampleRate: sampleRate,
                channel: channel,
                clickNote: Self.clickNote,
                noteOffDelaySamples: noteOffDelay
            )
            allEvents.append(contentsOf: beatEvents)
        }

        return Batch(events: allEvents, beats: beats)
    }
}

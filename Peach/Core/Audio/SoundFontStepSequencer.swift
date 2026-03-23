import Foundation
import os

// MARK: - StepSequencerEngine

protocol StepSequencerEngine {
    var sampleRate: SampleRate { get }
    var currentSamplePosition: Int64 { get }
    func ensureAudioSessionConfigured() throws
    func ensureEngineRunning() throws
    func loadPreset(_ preset: SF2Preset, channel: SoundFontEngine.ChannelID) async throws
    func scheduleEvents(_ events: [ScheduledMIDIEvent])
    func clearSchedule()
    func stopNotes(channel: SoundFontEngine.ChannelID, stopPropagationDelay: Duration) async
    func immediateNoteOn(channel: SoundFontEngine.ChannelID, note: UInt8, velocity: UInt8)
    func immediateNoteOff(channel: SoundFontEngine.ChannelID, note: UInt8)
}

extension SoundFontEngine: StepSequencerEngine {}

// MARK: - SoundFontStepSequencer

@Observable
final class SoundFontStepSequencer: StepSequencer {

    // MARK: - Constants

    private nonisolated static let clickNote = MIDINote(76)
    private nonisolated static let noteOffDuration: Duration = .milliseconds(50)

    /// Number of cycles to schedule in each batch. At 60 BPM each cycle is 1 second,
    /// so 500 cycles ≈ 8+ minutes of audio — well within the engine's 4096-event buffer
    /// (each cycle produces at most 6 events: 3 note-on + 3 note-off).
    private nonisolated static let cyclesPerBatch = 500

    /// Polling interval for sample-position-driven UI tracking (~120 Hz).
    private nonisolated static let uiPollingInterval: Duration = .milliseconds(8)

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontStepSequencer")

    // MARK: - Dependencies

    private let engine: any StepSequencerEngine
    private let channel: SoundFontEngine.ChannelID
    private let preset: SF2Preset

    // MARK: - Observable State

    private(set) var currentStep: StepPosition?
    private(set) var currentCycle: CycleDefinition?

    // MARK: - State

    private var runLoopTask: Task<Void, any Error>?
    private var noteOffTask: Task<Void, Never>?

    // MARK: - Initialization

    init(engine: any StepSequencerEngine, preset: SF2Preset, channel: SoundFontEngine.ChannelID) {
        self.engine = engine
        self.preset = preset
        self.channel = channel
    }

    // MARK: - StepSequencer Protocol

    func start(tempo: TempoBPM, stepProvider: any StepProvider) async throws {
        try await stop()

        try engine.ensureAudioSessionConfigured()
        try engine.ensureEngineRunning()
        try await engine.loadPreset(preset, channel: channel)

        let sampleRate = engine.sampleRate
        let samplesPerStep = Self.samplesPerStep(tempo: tempo, sampleRate: sampleRate)
        let noteOffDelaySamples = Self.noteOffDelaySamples(
            sampleRate: sampleRate,
            samplesPerStep: samplesPerStep
        )
        let samplesPerCycle = samplesPerStep * 4

        let batch = Self.buildBatch(
            cycleCount: Self.cyclesPerBatch,
            stepProvider: stepProvider,
            samplesPerStep: samplesPerStep,
            noteOffDelaySamples: noteOffDelaySamples,
            channelID: channel
        )
        engine.scheduleEvents(batch.events)

        logger.info("Step sequencer started at \(tempo.value) BPM")

        let refillThreshold = Int64(Self.cyclesPerBatch - 10) * samplesPerCycle

        runLoopTask = Task {
            var definitions = batch.definitions

            while !Task.isCancelled {
                let position = engine.currentSamplePosition

                // Derive UI state from the engine's actual sample position
                let globalStepIndex = position / samplesPerStep
                let stepInCycle = Int(globalStepIndex % 4)
                let cycleIndex = Int(globalStepIndex / 4)

                currentStep = StepPosition(rawValue: stepInCycle)
                currentCycle = definitions[cycleIndex % definitions.count]

                // Replenish batch when approaching the end
                if position >= refillThreshold {
                    let nextBatch = Self.buildBatch(
                        cycleCount: Self.cyclesPerBatch,
                        stepProvider: stepProvider,
                        samplesPerStep: samplesPerStep,
                        noteOffDelaySamples: noteOffDelaySamples,
                        channelID: channel
                    )
                    definitions = nextBatch.definitions
                    engine.scheduleEvents(nextBatch.events)
                }

                try await Task.sleep(for: Self.uiPollingInterval)
            }
        }
    }

    func playImmediateNote(velocity: MIDIVelocity) throws {
        let midiNoteRaw = UInt8(Self.clickNote.rawValue)

        noteOffTask?.cancel()
        engine.immediateNoteOn(channel: channel, note: midiNoteRaw, velocity: velocity.rawValue)

        noteOffTask = Task { [engine, channel] in
            try? await Task.sleep(for: Self.noteOffDuration)
            guard !Task.isCancelled else { return }
            engine.immediateNoteOff(channel: channel, note: midiNoteRaw)
        }
    }

    func stop() async throws {
        noteOffTask?.cancel()
        noteOffTask = nil
        runLoopTask?.cancel()
        _ = await runLoopTask?.result
        runLoopTask = nil
        currentStep = nil
        currentCycle = nil
        engine.clearSchedule()
        await engine.stopNotes(channel: channel, stopPropagationDelay: .zero)
        logger.info("Step sequencer stopped")
    }

    // MARK: - Event Building (pure, testable)

    static func samplesPerStep(tempo: TempoBPM, sampleRate: SampleRate) -> Int64 {
        Int64(sampleRate.rawValue * tempo.sixteenthNoteDuration.timeInterval)
    }

    static func noteOffDelaySamples(
        sampleRate: SampleRate,
        samplesPerStep: Int64
    ) -> Int64 {
        let noteOffSamples = Int64(sampleRate.rawValue * Self.noteOffDuration.timeInterval)
        return min(noteOffSamples, max(samplesPerStep - 1, 1))
    }

    static func buildCycleEvents(
        cycle: CycleDefinition,
        cycleOffset: Int64,
        samplesPerStep: Int64,
        noteOffDelaySamples: Int64,
        channelID: SoundFontEngine.ChannelID
    ) -> [ScheduledMIDIEvent] {
        var events: [ScheduledMIDIEvent] = []
        events.reserveCapacity(6)

        let midiNoteRaw = UInt8(clickNote.rawValue)
        let channelRaw = channelID.rawValue

        for step in StepPosition.allCases {
            if step == cycle.gapPosition { continue }

            let velocity = step == .first ? StepVelocity.accent : StepVelocity.normal
            let stepOffset = cycleOffset + Int64(step.rawValue) * samplesPerStep

            events.append(ScheduledMIDIEvent(
                sampleOffset: stepOffset,
                midiStatus: SoundFontEngine.noteOnBase | channelRaw,
                midiNote: midiNoteRaw,
                velocity: velocity.rawValue
            ))

            events.append(ScheduledMIDIEvent(
                sampleOffset: stepOffset + noteOffDelaySamples,
                midiStatus: SoundFontEngine.noteOffBase | channelRaw,
                midiNote: midiNoteRaw,
                velocity: 0
            ))
        }

        return events
    }

    struct Batch {
        let events: [ScheduledMIDIEvent]
        let definitions: [CycleDefinition]
    }

    static func buildBatch(
        cycleCount: Int,
        stepProvider: any StepProvider,
        samplesPerStep: Int64,
        noteOffDelaySamples: Int64,
        channelID: SoundFontEngine.ChannelID
    ) -> Batch {
        let samplesPerCycle = samplesPerStep * 4
        var allEvents: [ScheduledMIDIEvent] = []
        allEvents.reserveCapacity(cycleCount * 6)
        var definitions: [CycleDefinition] = []
        definitions.reserveCapacity(cycleCount)

        for cycleIndex in 0..<cycleCount {
            let cycle = stepProvider.nextCycle()
            definitions.append(cycle)
            let cycleOffset = Int64(cycleIndex) * samplesPerCycle

            let cycleEvents = buildCycleEvents(
                cycle: cycle,
                cycleOffset: cycleOffset,
                samplesPerStep: samplesPerStep,
                noteOffDelaySamples: noteOffDelaySamples,
                channelID: channelID
            )
            allEvents.append(contentsOf: cycleEvents)
        }

        return Batch(events: allEvents, definitions: definitions)
    }
}

import Foundation
import os

@Observable
final class SoundFontStepSequencer: StepSequencer {

    // MARK: - Constants

    private nonisolated static let clickNote = MIDINote(76)
    private nonisolated static let noteOffDuration: Duration = .milliseconds(50)

    /// Number of cycles to schedule in each batch. At 60 BPM each cycle is 1 second,
    /// so 500 cycles ≈ 8+ minutes of audio — well within the engine's 4096-event buffer
    /// (each cycle produces at most 6 events: 3 note-on + 3 note-off).
    private nonisolated static let cyclesPerBatch = 500

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontStepSequencer")

    // MARK: - Dependencies

    private let engine: SoundFontEngine
    private let channel: SoundFontEngine.ChannelID
    private let preset: SF2Preset

    // MARK: - Observable State

    private(set) var currentStep: StepPosition?
    private(set) var currentCycle: CycleDefinition?

    // MARK: - State

    private var sequencerTask: Task<Void, any Error>?
    private var uiTrackingTask: Task<Void, any Error>?
    private var batchCycleDefinitions: [CycleDefinition] = []

    // MARK: - Initialization

    init(engine: SoundFontEngine, preset: SF2Preset, channel: SoundFontEngine.ChannelID) {
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
        let cycleDuration = tempo.sixteenthNoteDuration.timeInterval * 4.0

        let batch = Self.buildBatch(
            cycleCount: Self.cyclesPerBatch,
            stepProvider: stepProvider,
            samplesPerStep: samplesPerStep,
            noteOffDelaySamples: noteOffDelaySamples,
            channelID: channel
        )
        batchCycleDefinitions = batch.definitions
        engine.scheduleEvents(batch.events)

        logger.info("Step sequencer started at \(tempo.value) BPM")

        let stepDuration = tempo.sixteenthNoteDuration

        // UI tracking: advance currentStep and currentCycle in sync with audio
        uiTrackingTask = Task {
            var cycleIndex = 0
            while !Task.isCancelled {
                let definition = batchCycleDefinitions[cycleIndex % batchCycleDefinitions.count]
                currentCycle = definition
                for step in StepPosition.allCases {
                    if Task.isCancelled { return }
                    currentStep = step
                    try await Task.sleep(for: stepDuration)
                }
                cycleIndex += 1
            }
        }

        sequencerTask = Task {
            let sleepDuration = cycleDuration * Double(Self.cyclesPerBatch - 10)
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(sleepDuration))
                if Task.isCancelled { return }

                let nextBatch = Self.buildBatch(
                    cycleCount: Self.cyclesPerBatch,
                    stepProvider: stepProvider,
                    samplesPerStep: samplesPerStep,
                    noteOffDelaySamples: noteOffDelaySamples,
                    channelID: channel
                )
                batchCycleDefinitions = nextBatch.definitions
                engine.scheduleEvents(nextBatch.events)
            }
        }
    }

    func stop() async throws {
        uiTrackingTask?.cancel()
        uiTrackingTask = nil
        sequencerTask?.cancel()
        sequencerTask = nil
        currentStep = nil
        currentCycle = nil
        batchCycleDefinitions = []
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

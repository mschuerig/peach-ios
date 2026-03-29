@preconcurrency import AVFoundation
import os
import Synchronization

// MARK: - Scheduled MIDI Event

/// A MIDI event scheduled for sample-accurate dispatch on the audio render thread.
struct ScheduledMIDIEvent: Sendable {
    let sampleOffset: Int64
    let midiStatus: UInt8
    let midiNote: UInt8
    let velocity: UInt8
}

// MARK: - Double-Buffered Schedule State

/// Lock-free double-buffered state shared between the main thread and the audio render thread.
///
/// **Safety invariant:** The active slot (read by the render thread) is never written by the
/// main thread. The main thread writes only to the inactive slot, then atomically increments
/// the generation counter (with release ordering) to swap. The render thread loads the
/// generation (with acquire ordering) before reading slot data, ensuring all writes are visible.
///
/// The active slot index is `generation % 2`. This single atomic operation publishes both the
/// generation change and the slot swap, eliminating any window where the render thread could
/// see a partially-written schedule.
nonisolated private final class DoubleBufferedScheduleState: @unchecked Sendable {

    // MARK: - Generation Counter

    /// Monotonically increasing counter. Active slot = `generation % 2`.
    let generation: Atomic<Int>

    // MARK: - Event Buffers (two slots)

    private let eventBuffer0: UnsafeMutablePointer<ScheduledMIDIEvent>
    private let eventBuffer1: UnsafeMutablePointer<ScheduledMIDIEvent>
    let capacity: Int

    /// Event counts per slot. No concurrent access to the same slot due to double-buffering;
    /// visibility guaranteed by the generation counter's release/acquire fence.
    private var count0: Int = 0
    private var count1: Int = 0

    // MARK: - MIDI Blocks (two slots × 16 channels)

    /// Pre-allocated 16-element arrays for MIDI dispatch blocks, one per slot.
    /// Copied from the main thread's authoritative dictionary on each schedule update.
    private let midiBlocks0: UnsafeMutablePointer<AUScheduleMIDIEventBlock?>
    private let midiBlocks1: UnsafeMutablePointer<AUScheduleMIDIEventBlock?>

    // MARK: - Render-Thread Cursor (only accessed by the single audio render thread)

    var nextIndex: Int = 0
    var lastGeneration: Int = 0

    // MARK: - Cross-Thread Timing (written by render thread, read by main thread)

    let samplePosition: Atomic<Int64>
    let hostTimeAtSample: Atomic<UInt64>
    let hostTimeSamplePosition: Atomic<Int64>

    // MARK: - Dispatch Counter (for test verification of AC#4)

    let dispatchedEventCount: Atomic<Int>

    // MARK: - Lifecycle

    init(capacity: Int) {
        self.capacity = capacity
        self.generation = Atomic<Int>(0)
        self.samplePosition = Atomic<Int64>(0)
        self.hostTimeAtSample = Atomic<UInt64>(0)
        self.hostTimeSamplePosition = Atomic<Int64>(0)
        self.dispatchedEventCount = Atomic<Int>(0)

        eventBuffer0 = .allocate(capacity: capacity)
        eventBuffer1 = .allocate(capacity: capacity)
        midiBlocks0 = .allocate(capacity: 16)
        midiBlocks1 = .allocate(capacity: 16)
        midiBlocks0.initialize(repeating: nil, count: 16)
        midiBlocks1.initialize(repeating: nil, count: 16)
    }

    deinit {
        eventBuffer0.deallocate()
        eventBuffer1.deallocate()
        midiBlocks0.deinitialize(count: 16)
        midiBlocks0.deallocate()
        midiBlocks1.deinitialize(count: 16)
        midiBlocks1.deallocate()
    }

    // MARK: - Slot Accessors

    func eventBuffer(forSlot slot: Int) -> UnsafeMutablePointer<ScheduledMIDIEvent> {
        slot == 0 ? eventBuffer0 : eventBuffer1
    }

    func count(forSlot slot: Int) -> Int {
        slot == 0 ? count0 : count1
    }

    func setCount(_ count: Int, forSlot slot: Int) {
        if slot == 0 { count0 = count } else { count1 = count }
    }

    func midiBlocks(forSlot slot: Int) -> UnsafeMutablePointer<AUScheduleMIDIEventBlock?> {
        slot == 0 ? midiBlocks0 : midiBlocks1
    }
}

final class SoundFontEngine {

    // MARK: - ChannelID

    struct ChannelID: Hashable, Sendable {
        let rawValue: UInt8
        init(_ rawValue: UInt8) {
            precondition((0...15).contains(rawValue), "MIDI channel must be 0-15, got \(rawValue)")
            self.rawValue = rawValue
        }
    }

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontEngine")

    // MARK: - Audio Components

    private let engine: AVAudioEngine
    private var channels: [ChannelID: AVAudioUnitSampler] = [:]
    private let sourceNode: AVAudioSourceNode

    // MARK: - State

    private var loadedPresets: [ChannelID: SF2Preset] = [:]
    private var activeMuteCount = 0

    // MARK: - MIDI Constants

    nonisolated static let noteOnBase: UInt8 = 0x90
    nonisolated static let noteOffBase: UInt8 = 0x80
    private nonisolated static let channelMask: UInt8 = 0x0F

    /// Pitch bend range in semitones, set via MIDI RPN in `sendPitchBendRange()`.
    /// All pitch bend calculations derive their cent limits from this value.
    nonisolated static let pitchBendRangeSemitones: Int = 2

    /// Maximum pitch bend displacement in cents, derived from `pitchBendRangeSemitones`.
    nonisolated static let pitchBendRangeCents: Double = Double(pitchBendRangeSemitones) * 100.0

    private nonisolated static let scheduleCapacity = 4096

    // MARK: - SF2 URL

    private let sf2URL: URL

    // MARK: - Lock-Free Schedule State

    /// Double-buffered schedule state for lock-free render-thread access.
    /// The render thread reads the active slot without blocking; the main thread
    /// writes to the inactive slot and atomically swaps via the generation counter.
    private let scheduleState: DoubleBufferedScheduleState

    /// Main-thread authoritative MIDI block dictionary. Copied into the inactive slot
    /// on each `scheduleEvents` call so the render thread has a consistent snapshot.
    private var mainThreadMidiBlocks: [UInt8: AUScheduleMIDIEventBlock] = [:]

    // MARK: - Initialization

    private let audioSessionConfigurator: AudioSessionConfiguring

    init(sf2URL: URL, audioSessionConfigurator: AudioSessionConfiguring) throws {
        self.sf2URL = sf2URL
        self.audioSessionConfigurator = audioSessionConfigurator

        let engine = AVAudioEngine()
        self.engine = engine

        let shared = DoubleBufferedScheduleState(capacity: Self.scheduleCapacity)
        self.scheduleState = shared

        // Pre-create channel 0 for backward compatibility
        let channel0 = ChannelID(0)
        let sampler0 = AVAudioUnitSampler()
        engine.attach(sampler0)
        engine.connect(sampler0, to: engine.mainMixerNode, format: nil)
        channels[channel0] = sampler0

        try audioSessionConfigurator.configure(logger: Self.audioSessionLogger)
        try engine.start()

        // Register MIDI block for channel 0 (available after engine start).
        // Safe to write both slots here — the source node (render thread) is not
        // yet attached to the engine, so no concurrent reader exists.
        let block0 = sampler0.auAudioUnit.scheduleMIDIEventBlock
        mainThreadMidiBlocks[channel0.rawValue] = block0
        shared.midiBlocks(forSlot: 0)[Int(channel0.rawValue)] = block0
        shared.midiBlocks(forSlot: 1)[Int(channel0.rawValue)] = block0

        // Create source node (outputs silence, serves as render-thread clock)
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let sourceNode = AVAudioSourceNode(format: sourceFormat) { @Sendable
            isSilence, timestamp, frameCount, outputData -> OSStatus in

            isSilence.pointee = true
            let abl = UnsafeMutableAudioBufferListPointer(outputData)
            for buf in abl {
                if let data = buf.mData {
                    memset(data, 0, Int(buf.mDataByteSize))
                }
            }

            // Load generation with acquire ordering — ensures all slot writes
            // from the main thread's release store are visible.
            let gen = shared.generation.load(ordering: .acquiring)
            let slotIndex = gen % 2

            // Detect schedule change — reset cursor and dispatch counter
            if gen != shared.lastGeneration {
                shared.lastGeneration = gen
                shared.nextIndex = 0
                shared.samplePosition.store(0, ordering: .relaxed)
                shared.dispatchedEventCount.store(0, ordering: .relaxed)
            }

            let count = shared.count(forSlot: slotIndex)
            guard count > 0 else { return noErr }

            let events = shared.eventBuffer(forSlot: slotIndex)
            let midiBlocks = shared.midiBlocks(forSlot: slotIndex)
            var nextIdx = shared.nextIndex
            let windowStart = shared.samplePosition.load(ordering: .relaxed)
            let windowEnd = windowStart + Int64(frameCount)

            while nextIdx < count {
                let event = events[nextIdx]
                if event.sampleOffset >= windowEnd { break }
                if event.sampleOffset >= windowStart {
                    let channel = event.midiStatus & Self.channelMask
                    guard let midiBlock = midiBlocks[Int(channel)] else {
                        nextIdx += 1
                        continue
                    }
                    let intraBufferOffset = event.sampleOffset - windowStart
                    let eventTime = AUEventSampleTimeImmediate
                        + AUEventSampleTime(intraBufferOffset)
                    var midiBytes = (event.midiStatus, event.midiNote, event.velocity)
                    withUnsafeBytes(of: &midiBytes) { rawBuffer in
                        midiBlock(eventTime, 0, 3, rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self))
                    }
                    shared.dispatchedEventCount.wrappingAdd(1, ordering: .relaxed)
                }
                nextIdx += 1
            }

            shared.nextIndex = nextIdx
            // Store timing values BEFORE the releasing samplePosition store so that
            // a reader who acquires samplePosition sees consistent timing state.
            shared.hostTimeAtSample.store(timestamp.pointee.mHostTime, ordering: .relaxed)
            shared.hostTimeSamplePosition.store(windowStart, ordering: .relaxed)
            shared.samplePosition.store(windowEnd, ordering: .releasing)

            return noErr
        }
        self.sourceNode = sourceNode

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: sourceFormat)

        logger.info("SoundFontEngine initialized with \(sf2URL.lastPathComponent)")
    }

    isolated deinit {
        engine.stop()
    }

    // MARK: - Sample Rate

    var sampleRate: SampleRate {
        SampleRate(engine.outputNode.outputFormat(forBus: 0).sampleRate)
    }

    // MARK: - Channel Management

    func createChannel(_ id: ChannelID) throws {
        guard channels[id] == nil else { return }

        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        channels[id] = sampler

        let block = sampler.auAudioUnit.scheduleMIDIEventBlock
        mainThreadMidiBlocks[id.rawValue] = block

        // Publish the new MIDI block via the double-buffer protocol: write to the
        // inactive slot and bump generation. This respects the invariant that the
        // active slot (read by the render thread) is never written by the main thread.
        let currentGen = scheduleState.generation.load(ordering: .relaxed)
        let inactiveIndex = (currentGen + 1) % 2
        let inactiveBlocks = scheduleState.midiBlocks(forSlot: inactiveIndex)
        // Copy all current MIDI blocks into the inactive slot
        for ch in 0..<16 {
            inactiveBlocks[ch] = mainThreadMidiBlocks[UInt8(ch)]
        }
        // Preserve the inactive slot's event count (carry forward from current active slot)
        let activeCount = scheduleState.count(forSlot: currentGen % 2)
        let activeEvents = scheduleState.eventBuffer(forSlot: currentGen % 2)
        let inactiveEvents = scheduleState.eventBuffer(forSlot: inactiveIndex)
        for i in 0..<activeCount {
            inactiveEvents[i] = activeEvents[i]
        }
        scheduleState.setCount(activeCount, forSlot: inactiveIndex)
        scheduleState.generation.store(currentGen + 1, ordering: .releasing)

        logger.info("Created channel \(id.rawValue)")
    }

    // MARK: - Audio Session & Engine Lifecycle

    func ensureAudioSessionConfigured() throws {
        try audioSessionConfigurator.configure(logger: Self.audioSessionLogger)
    }

    func ensureEngineRunning() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    // MARK: - Preset Loading

    func loadPreset(_ preset: SF2Preset, channel: ChannelID) async throws {
        guard let sampler = channels[channel] else {
            throw AudioError.invalidPreset("Channel \(channel.rawValue) does not exist")
        }
        guard (0...127).contains(preset.program) else {
            throw AudioError.invalidPreset("Program \(preset.program) outside valid MIDI range 0-127")
        }
        if preset.isPercussion {
            guard preset.bank == SF2Preset.percussionBank else {
                throw AudioError.invalidPreset("Bank \(preset.bank) outside valid range")
            }
        } else {
            guard (0...127).contains(preset.bank) else {
                throw AudioError.invalidPreset("Bank \(preset.bank) outside valid range 0-127")
            }
        }
        guard preset != loadedPresets[channel] else { return }

        let bankLSB: UInt8 = preset.isPercussion ? 0 : UInt8(clamping: preset.bank)
        try sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: UInt8(clamping: preset.program),
            bankMSB: preset.bankMSB,
            bankLSB: bankLSB
        )

        loadedPresets[channel] = preset

        if !preset.isPercussion {
            sendPitchBendRange(channel: channel)
        }

        // Allow audio graph to settle after instrument load — without this delay
        // the first MIDI note-on after a preset switch produces no sound.
        try await Task.sleep(for: .milliseconds(20))

        logger.info("Loaded preset \(preset.rawValue) on channel \(channel.rawValue)")
    }

    // MARK: - Immediate MIDI Dispatch

    func startNote(_ midiNote: MIDINote, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB, pitchBend: PitchBendValue, channel: ChannelID) {
        guard let sampler = channels[channel] else { return }
        sampler.sendPitchBend(pitchBend.rawValue, onChannel: channel.rawValue)
        sampler.overallGain = Float(amplitudeDB.rawValue)
        sampler.startNote(UInt8(midiNote.rawValue), withVelocity: velocity.rawValue, onChannel: channel.rawValue)
    }

    func stopNote(_ midiNote: MIDINote, channel: ChannelID) {
        guard let sampler = channels[channel] else { return }
        sampler.stopNote(UInt8(midiNote.rawValue), onChannel: channel.rawValue)
    }

    func stopNotes(channel: ChannelID, stopPropagationDelay: Duration) async {
        guard let sampler = channels[channel] else { return }
        if stopPropagationDelay > .zero {
            muteForFade()
            try? await Task.sleep(for: stopPropagationDelay)
        }
        sampler.sendController(123, withValue: 0, onChannel: channel.rawValue)
        sampler.sendPitchBend(PitchBendValue.center.rawValue, onChannel: channel.rawValue)
        if stopPropagationDelay > .zero {
            restoreAfterFade()
        }
    }

    func immediateNoteOn(channel: ChannelID, note: UInt8, velocity: UInt8) {
        guard let sampler = channels[channel] else { return }
        sampler.startNote(note, withVelocity: velocity, onChannel: channel.rawValue)
    }

    func immediateNoteOff(channel: ChannelID, note: UInt8) {
        guard let sampler = channels[channel] else { return }
        sampler.stopNote(note, onChannel: channel.rawValue)
    }

    func sendPitchBend(_ value: PitchBendValue, channel: ChannelID) {
        guard let sampler = channels[channel] else { return }
        sampler.sendPitchBend(value.rawValue, onChannel: channel.rawValue)
    }

    // MARK: - Volume Fade

    func muteForFade() {
        activeMuteCount += 1
        for sampler in channels.values {
            sampler.volume = 0
        }
    }

    func restoreAfterFade() {
        activeMuteCount -= 1
        if activeMuteCount <= 0 {
            activeMuteCount = 0
            for sampler in channels.values {
                sampler.volume = 1.0
            }
        }
    }

    private static let audioSessionLogger = Logger(subsystem: "com.peach.app", category: "SoundFontEngine")

    // MARK: - Render-Thread Scheduling

    func scheduleEvents(_ events: [ScheduledMIDIEvent]) {
        if events.count > Self.scheduleCapacity {
            logger.warning("Schedule overflow: \(events.count) events exceeds buffer capacity \(Self.scheduleCapacity), truncating")
            assertionFailure("Schedule overflow: \(events.count) events exceeds buffer capacity \(Self.scheduleCapacity)")
        }
        // Reset only samplers on channels referenced by the new events to flush
        // stale MIDI events without disrupting other active channels.
        var affectedChannels: Set<UInt8> = []
        for event in events {
            affectedChannels.insert(event.midiStatus & Self.channelMask)
        }
        for channelID in affectedChannels {
            if let sampler = channels[ChannelID(channelID)] {
                sampler.auAudioUnit.reset()
            }
        }

        // Write to the inactive slot, then atomically swap via generation increment
        let currentGen = scheduleState.generation.load(ordering: .relaxed)
        let inactiveIndex = (currentGen + 1) % 2
        let buffer = scheduleState.eventBuffer(forSlot: inactiveIndex)
        let count = min(events.count, scheduleState.capacity)
        for i in 0..<count {
            buffer[i] = events[i]
        }
        scheduleState.setCount(count, forSlot: inactiveIndex)

        // Copy current MIDI blocks into the inactive slot
        let inactiveBlocks = scheduleState.midiBlocks(forSlot: inactiveIndex)
        for ch in 0..<16 {
            inactiveBlocks[ch] = mainThreadMidiBlocks[UInt8(ch)]
        }

        // Atomic publish — release fence ensures all writes above are visible
        // to the render thread's acquire load of the generation counter.
        scheduleState.generation.store(currentGen + 1, ordering: .releasing)
    }

    func clearSchedule() {
        let currentGen = scheduleState.generation.load(ordering: .relaxed)
        let inactiveIndex = (currentGen + 1) % 2
        scheduleState.setCount(0, forSlot: inactiveIndex)

        // Atomic publish — render thread resets samplePosition to 0 on generation change
        // detection. Do NOT reset timing atomics here: the render thread may be mid-callback
        // reading them on the old generation, and a zeroed samplePosition could cause
        // re-dispatch of events in the current schedule.
        scheduleState.generation.store(currentGen + 1, ordering: .releasing)
    }

    var scheduledEventCount: Int {
        let gen = scheduleState.generation.load(ordering: .acquiring)
        return scheduleState.count(forSlot: gen % 2)
    }

    var dispatchedEventCount: Int {
        scheduleState.dispatchedEventCount.load(ordering: .acquiring)
    }

    var currentSamplePosition: Int64 {
        scheduleState.samplePosition.load(ordering: .acquiring)
    }

    func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
        // Load samplePosition first with acquire ordering — this pairs with the
        // render thread's releasing store and guarantees that the subsequent relaxed
        // loads of hostTimeAtSample and hostTimeSamplePosition see values that were
        // stored before the release fence.
        let currentPos = scheduleState.samplePosition.load(ordering: .acquiring)
        let knownHostTime = scheduleState.hostTimeAtSample.load(ordering: .relaxed)
        let knownSamplePos = scheduleState.hostTimeSamplePosition.load(ordering: .relaxed)
        guard knownHostTime != 0 else {
            return currentPos
        }

        let deltaTicks = Int64(hostTime) - Int64(knownHostTime)
        let numer = Int64(Self.timebaseInfo.numer)
        let denom = Int64(Self.timebaseInfo.denom)
        let deltaNanos = deltaTicks / denom * numer + (deltaTicks % denom) * numer / denom
        let deltaSeconds = Double(deltaNanos) / 1_000_000_000.0
        return knownSamplePos + Int64(deltaSeconds * sampleRate.rawValue)
    }

    private nonisolated static let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    // MARK: - Schedule Scanning (testable pure function)

    nonisolated static func scanSchedule(
        events: [ScheduledMIDIEvent],
        fromIndex: Int,
        windowStart: Int64,
        windowEnd: Int64
    ) -> (dispatched: [ScheduledMIDIEvent], nextIndex: Int) {
        var dispatched: [ScheduledMIDIEvent] = []
        var index = fromIndex
        while index < events.count {
            let event = events[index]
            if event.sampleOffset >= windowEnd { break }
            if event.sampleOffset >= windowStart {
                dispatched.append(event)
            }
            index += 1
        }
        return (dispatched, index)
    }

    // MARK: - MIDI Helpers

    private func sendPitchBendRange(channel: ChannelID) {
        guard let sampler = channels[channel] else { return }
        // MIDI RPN 0x0000 (Pitch Bend Sensitivity): set range to ±pitchBendRangeSemitones
        sampler.sendController(101, withValue: 0, onChannel: channel.rawValue)   // RPN MSB
        sampler.sendController(100, withValue: 0, onChannel: channel.rawValue)   // RPN LSB
        sampler.sendController(6, withValue: UInt8(Self.pitchBendRangeSemitones), onChannel: channel.rawValue)  // Data Entry MSB (semitones)
        sampler.sendController(38, withValue: 0, onChannel: channel.rawValue)    // Data Entry LSB (cents)
    }
}

@preconcurrency import AVFoundation
import os

// MARK: - Scheduled MIDI Event

/// A MIDI event scheduled for sample-accurate dispatch on the audio render thread.
struct ScheduledMIDIEvent: Sendable {
    let sampleOffset: Int64
    let midiStatus: UInt8
    let midiNote: UInt8
    let velocity: UInt8
}

// MARK: - Schedule Data

/// All mutable state shared between the render thread and the main thread.
/// Access is synchronized via `OSAllocatedUnfairLock`.
nonisolated private struct ScheduleData: @unchecked Sendable {
    let buffer: UnsafeMutablePointer<ScheduledMIDIEvent>
    let capacity: Int
    var count: Int = 0
    var nextIndex: Int = 0
    var samplePosition: Int64 = 0
    var hostTimeAtSample: UInt64 = 0
    var midiBlocks: [UInt8: AUScheduleMIDIEventBlock] = [:]
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

    // MARK: - Render-Thread Schedule Storage

    /// Pre-allocated event buffer, owned by SoundFontEngine for deallocation.
    private let scheduleBuffer: UnsafeMutablePointer<ScheduledMIDIEvent>

    /// Synchronized access to schedule state. The render thread uses `withLockIfAvailable`
    /// (try-lock, non-blocking) so it never stalls the audio pipeline. The main thread
    /// uses `withLock` (blocking, acceptable off the render thread).
    private let scheduleLockState: OSAllocatedUnfairLock<ScheduleData>

    // MARK: - Initialization

    init(sf2URL: URL) throws {
        self.sf2URL = sf2URL

        let engine = AVAudioEngine()
        self.engine = engine

        // Pre-allocate event buffer — deallocate on throw since deinit won't run
        let scheduleBuffer = UnsafeMutablePointer<ScheduledMIDIEvent>.allocate(capacity: Self.scheduleCapacity)
        self.scheduleBuffer = scheduleBuffer
        var didFinishInit = false
        defer { if !didFinishInit { scheduleBuffer.deallocate() } }

        // Create lock state (no MIDI blocks yet — added when channels are created)
        let lockState = OSAllocatedUnfairLock(initialState: ScheduleData(
            buffer: scheduleBuffer,
            capacity: Self.scheduleCapacity
        ))
        self.scheduleLockState = lockState

        // Pre-create channel 0 for backward compatibility
        let channel0 = ChannelID(0)
        let sampler0 = AVAudioUnitSampler()
        engine.attach(sampler0)
        engine.connect(sampler0, to: engine.mainMixerNode, format: nil)
        channels[channel0] = sampler0

        try Self.configureAudioSession()
        try engine.start()

        // Register MIDI block for channel 0 (available after engine start)
        lockState.withLock { data in
            data.midiBlocks[channel0.rawValue] = sampler0.auAudioUnit.scheduleMIDIEventBlock
        }

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

            // Try-lock: if the main thread is updating the schedule, skip this frame
            // rather than blocking the audio render thread.
            _ = lockState.withLockIfAvailable { data in
                guard data.count > 0 else { return }

                let windowStart = data.samplePosition
                let windowEnd = windowStart + Int64(frameCount)

                while data.nextIndex < data.count {
                    let event = data.buffer[data.nextIndex]
                    if event.sampleOffset >= windowEnd { break }
                    if event.sampleOffset >= windowStart {
                        let channel = event.midiStatus & Self.channelMask
                        guard let midiBlock = data.midiBlocks[channel] else {
                            data.nextIndex += 1
                            continue
                        }
                        // Use AUEventSampleTimeImmediate + offset so the sampler
                        // always interprets events relative to "now" rather than
                        // as absolute timestamps that may already be past.
                        let intraBufferOffset = event.sampleOffset - windowStart
                        let eventTime = AUEventSampleTimeImmediate
                            + AUEventSampleTime(intraBufferOffset)
                        var midiBytes = (event.midiStatus, event.midiNote, event.velocity)
                        withUnsafeBytes(of: &midiBytes) { rawBuffer in
                            midiBlock(eventTime, 0, 3, rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self))
                        }
                    }
                    data.nextIndex += 1
                }

                data.samplePosition = windowEnd
                data.hostTimeAtSample = timestamp.pointee.mHostTime
            }

            return noErr
        }
        self.sourceNode = sourceNode

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: sourceFormat)

        didFinishInit = true

        logger.info("SoundFontEngine initialized with \(sf2URL.lastPathComponent)")
    }

    isolated deinit {
        engine.stop()
        scheduleBuffer.deallocate()
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

        scheduleLockState.withLock { data in
            data.midiBlocks[id.rawValue] = sampler.auAudioUnit.scheduleMIDIEventBlock
        }

        logger.info("Created channel \(id.rawValue)")
    }

    // MARK: - Audio Session & Engine Lifecycle

    func ensureAudioSessionConfigured() throws {
        try Self.configureAudioSession()
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

    // MARK: - Audio Session

    private static let audioSessionLogger = Logger(subsystem: "com.peach.app", category: "SoundFontEngine")

    private static func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        let actualMs = session.ioBufferDuration * 1000
        audioSessionLogger.info("Requested 5ms buffer, got \(actualMs, format: .fixed(precision: 1))ms")
    }

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
        scheduleLockState.withLock { data in
            let count = min(events.count, data.capacity)
            for i in 0..<count {
                data.buffer[i] = events[i]
            }
            data.count = count
            data.nextIndex = 0
            data.samplePosition = 0
        }
    }

    func clearSchedule() {
        scheduleLockState.withLock { data in
            data.count = 0
            data.nextIndex = 0
            data.samplePosition = 0
            data.hostTimeAtSample = 0
        }
    }

    var scheduledEventCount: Int {
        scheduleLockState.withLock { data in data.count }
    }

    var currentSamplePosition: Int64 {
        scheduleLockState.withLock { data in data.samplePosition }
    }

    func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
        let (knownHostTime, knownSamplePos) = scheduleLockState.withLock { data in
            (data.hostTimeAtSample, data.samplePosition)
        }
        guard knownHostTime != 0 else { return knownSamplePos }

        let deltaTicks = Int64(hostTime) - Int64(knownHostTime)
        let deltaNanos = deltaTicks * Int64(Self.timebaseInfo.numer) / Int64(Self.timebaseInfo.denom)
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

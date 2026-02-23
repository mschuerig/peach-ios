import AVFoundation
import AVFAudio
import Foundation
import os

@MainActor
public final class SoundFontNotePlayer: NotePlayer {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontNotePlayer")

    // MARK: - Audio Components

    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler

    // MARK: - State

    private var currentNote: UInt8?
    private var isSessionConfigured = false

    // MARK: - Constants

    private static let channel: UInt8 = 0
    private static let celloProgram: UInt8 = 42
    private static let bankMSB: UInt8 = 0x79 // kAUSampler_DefaultMelodicBankMSB
    private static let bankLSB: UInt8 = 0
    private static let pitchBendCenter: UInt16 = 8192

    // MARK: - Initialization

    init(sf2Name: String = "GeneralUser-GS") throws {
        guard let sf2URL = Bundle.main.url(forResource: sf2Name, withExtension: "sf2") else {
            throw AudioError.contextUnavailable
        }

        self.engine = AVAudioEngine()
        self.sampler = AVAudioUnitSampler()

        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        try engine.start()
        try sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: Self.celloProgram,
            bankMSB: Self.bankMSB,
            bankLSB: Self.bankLSB
        )

        // Set pitch bend range to +/-2 semitones via RPN
        sampler.sendController(101, withValue: 0, onChannel: Self.channel)
        sampler.sendController(100, withValue: 0, onChannel: Self.channel)
        sampler.sendController(6, withValue: 2, onChannel: Self.channel)
        sampler.sendController(38, withValue: 0, onChannel: Self.channel)

        logger.info("SoundFontNotePlayer initialized with \(sf2Name).sf2, Cello preset")
    }

    // MARK: - NotePlayer Protocol

    public func play(frequency: Double, duration: TimeInterval, amplitude: Double) async throws {
        // Configure audio session once
        if !isSessionConfigured {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            isSessionConfigured = true
        }

        if !engine.isRunning {
            try engine.start()
        }

        let conversion = FrequencyCalculation.midiNoteAndCents(frequency: frequency)
        let midiNote = UInt8(clamping: conversion.midiNote)
        let bendValue = Self.pitchBendValue(forCents: conversion.cents)
        let velocity = Self.midiVelocity(forAmplitude: amplitude)

        // Apply pitch bend before starting note
        sampler.sendPitchBend(bendValue, onChannel: Self.channel)
        sampler.startNote(midiNote, withVelocity: velocity, onChannel: Self.channel)
        currentNote = midiNote

        defer {
            sampler.stopNote(midiNote, onChannel: Self.channel)
            sampler.sendPitchBend(Self.pitchBendCenter, onChannel: Self.channel)
            currentNote = nil
        }

        try await Task.sleep(for: .seconds(duration))
    }

    public func stop() async throws {
        if let note = currentNote {
            sampler.stopNote(note, onChannel: Self.channel)
            sampler.sendPitchBend(Self.pitchBendCenter, onChannel: Self.channel)
            currentNote = nil
        }
    }

    // MARK: - Static Helpers

    nonisolated static func pitchBendValue(forCents cents: Double) -> UInt16 {
        let raw = Int(8192.0 + cents * 8192.0 / 200.0)
        let clamped = Swift.min(16383, Swift.max(0, raw))
        return UInt16(clamped)
    }

    nonisolated static func midiVelocity(forAmplitude amplitude: Double) -> UInt8 {
        UInt8(Swift.min(127, Swift.max(1, Int(amplitude * 127.0))))
    }
}

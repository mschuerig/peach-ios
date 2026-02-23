import AVFoundation
import Foundation
import os

@MainActor
final class SoundFontNotePlayer: NotePlayer {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "SoundFontNotePlayer")

    // MARK: - Audio Components

    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler

    // MARK: - State

    private var currentNote: UInt8?
    private var isSessionConfigured = false
    private var loadedProgram: Int
    private var loadedBank: Int

    // MARK: - Constants

    private static let channel: UInt8 = 0
    private static let defaultBankMSB: UInt8 = 0x79 // kAUSampler_DefaultMelodicBankMSB
    private static let pitchBendCenter: UInt16 = 8192
    private static let validFrequencyRange = 20.0...20000.0

    // Default SF2 preset: Sine Wave (bank 8, program 80, tag "sf2:8:80")
    private static let defaultPresetProgram: Int = 80
    private static let defaultPresetBank: Int = 8

    // MARK: - SF2 URL

    private let sf2URL: URL

    // MARK: - Initialization

    init(sf2Name: String = "GeneralUser-GS") throws {
        guard let sf2URL = Bundle.main.url(forResource: sf2Name, withExtension: "sf2") else {
            throw AudioError.contextUnavailable
        }

        self.sf2URL = sf2URL
        self.engine = AVAudioEngine()
        self.sampler = AVAudioUnitSampler()
        self.loadedProgram = Self.defaultPresetProgram
        self.loadedBank = Self.defaultPresetBank

        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        try engine.start()
        try sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: UInt8(Self.defaultPresetProgram),
            bankMSB: Self.defaultBankMSB,
            bankLSB: UInt8(Self.defaultPresetBank)
        )

        sendPitchBendRange()

        logger.info("SoundFontNotePlayer initialized with \(sf2Name).sf2, program \(Self.defaultPresetProgram)")
    }

    // MARK: - Preset Switching

    func loadPreset(program: Int, bank: Int = 0) async throws {
        guard (0...127).contains(program) else {
            throw AudioError.invalidPreset("Program \(program) outside valid MIDI range 0-127")
        }
        guard (0...127).contains(bank) else {
            throw AudioError.invalidPreset("Bank \(bank) outside valid range 0-127")
        }
        guard program != loadedProgram || bank != loadedBank else { return }

        if let note = currentNote {
            sampler.stopNote(note, onChannel: Self.channel)
            currentNote = nil
        }

        try sampler.loadSoundBankInstrument(
            at: sf2URL,
            program: UInt8(clamping: program),
            bankMSB: Self.defaultBankMSB,
            bankLSB: UInt8(clamping: bank)
        )

        loadedProgram = program
        loadedBank = bank

        sendPitchBendRange()

        // Allow audio graph to settle after instrument load — without this delay
        // the first MIDI note-on after a preset switch produces no sound.
        try await Task.sleep(for: .milliseconds(20))

        logger.info("Loaded preset bank \(bank) program \(program)")
    }

    // MARK: - NotePlayer Protocol

    func play(frequency: Double, duration: TimeInterval, amplitude: Double) async throws {
        // Select preset from UserDefaults sound source setting
        let source = UserDefaults.standard.string(forKey: SettingsKeys.soundSource)
            ?? SettingsKeys.defaultSoundSource

        if let (bank, program) = Self.parseSF2Tag(from: source) {
            do {
                try await loadPreset(program: program, bank: bank)
            } catch {
                try await loadPreset(program: Self.defaultPresetProgram, bank: Self.defaultPresetBank)
            }
        } else {
            try await loadPreset(program: Self.defaultPresetProgram, bank: Self.defaultPresetBank)
        }

        // Validate inputs
        guard Self.validFrequencyRange.contains(frequency) else {
            throw AudioError.invalidFrequency(
                "Frequency \(frequency) Hz is outside valid range \(Self.validFrequencyRange)"
            )
        }
        guard duration > 0 else {
            throw AudioError.invalidDuration(
                "Duration \(duration) seconds must be positive"
            )
        }
        guard (0.0...1.0).contains(amplitude) else {
            throw AudioError.invalidAmplitude(
                "Amplitude \(amplitude) is outside valid range 0.0-1.0"
            )
        }

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
        let clampedNote = min(127, max(0, conversion.midiNote))
        let midiNote = UInt8(clampedNote)
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

    func stop() async throws {
        // Note: stop() halts audio output immediately but does not interrupt an in-progress
        // play() call's Task.sleep. The primary stop mechanism is task cancellation, which
        // causes Task.sleep to throw CancellationError and triggers the defer cleanup block.
        if let note = currentNote {
            sampler.stopNote(note, onChannel: Self.channel)
            sampler.sendPitchBend(Self.pitchBendCenter, onChannel: Self.channel)
            currentNote = nil
        }
    }

    // MARK: - MIDI Helpers

    private func sendPitchBendRange() {
        sampler.sendController(101, withValue: 0, onChannel: Self.channel)
        sampler.sendController(100, withValue: 0, onChannel: Self.channel)
        sampler.sendController(6, withValue: 2, onChannel: Self.channel)
        sampler.sendController(38, withValue: 0, onChannel: Self.channel)
    }

    // MARK: - Static Helpers

    nonisolated static func parseSF2Tag(from source: String) -> (bank: Int, program: Int)? {
        guard source.hasPrefix("sf2:") else { return nil }
        let parts = source.dropFirst(4).split(separator: ":")
        guard parts.count == 2,
              let bank = Int(parts[0]),
              let program = Int(parts[1]) else { return nil }
        return (bank: bank, program: program)
    }

    nonisolated static func pitchBendValue(forCents cents: Double) -> UInt16 {
        let raw = Int(8192.0 + cents * 8192.0 / 200.0)
        let clamped = Swift.min(16383, Swift.max(0, raw))
        return UInt16(clamped)
    }

    nonisolated static func midiVelocity(forAmplitude amplitude: Double) -> UInt8 {
        UInt8(Swift.min(127, Swift.max(1, Int(amplitude * 127.0))))
    }
}

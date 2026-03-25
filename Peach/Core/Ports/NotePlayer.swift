import Foundation

enum AudioError: Error {
    case engineStartFailed(String)
    case invalidFrequency(String)
    case invalidDuration(String)
    case invalidPreset(String)
    case contextUnavailable
    case invalidInterval(String)
}

protocol NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle

    func play(frequency: Frequency, duration: Duration, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws

    func stopAll() async throws
}

extension NotePlayer {
    func play(frequency: Frequency, duration: Duration, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws {
        guard duration > .zero else {
            throw AudioError.invalidDuration("Duration \(duration) must be positive")
        }
        let handle = try await play(frequency: frequency, velocity: velocity, amplitudeDB: amplitudeDB)
        do {
            try await Task.sleep(for: duration)
            try await handle.stop()
        } catch {
            try? await handle.stop()
            throw error
        }
    }
}

import Foundation

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

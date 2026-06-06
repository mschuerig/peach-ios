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
        } catch let error as CancellationError {
            // Don't call handle.stop on cancellation: it would register a chain entry from a deferred continuation and race a subsequent play(). Session-level scheduleStopAll silences via the chain that play() awaits.
            throw error
        } catch {
            try? await handle.stop()
            throw error
        }
    }
}

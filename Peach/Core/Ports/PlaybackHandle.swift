import Foundation

protocol PlaybackHandle {
    func stop() async throws
    func adjustFrequency(_ frequency: Frequency) async throws
}

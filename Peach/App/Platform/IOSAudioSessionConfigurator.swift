#if os(iOS)
import AVFoundation
import os

/// Configures the iOS audio session for low-latency playback.
struct IOSAudioSessionConfigurator: AudioSessionConfiguring {
    func configure(logger: Logger) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        let actualMs = session.ioBufferDuration * 1000
        logger.info("Requested 5ms buffer, got \(actualMs, format: .fixed(precision: 1))ms")
    }
}
#endif

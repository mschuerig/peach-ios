import os

/// Configures the platform's audio session for low-latency playback.
///
/// iOS: sets AVAudioSession category, buffer duration, and activates the session.
/// macOS: no-op (macOS has no AVAudioSession).
protocol AudioSessionConfiguring {
    func configure(logger: Logger) throws
}

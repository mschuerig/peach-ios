#if os(macOS)
import os

/// No-op audio session configurator for macOS (no AVAudioSession).
struct MacOSAudioSessionConfigurator: AudioSessionConfiguring {
    func configure(logger: Logger) throws {
        logger.info("Audio session configuration skipped on macOS")
    }
}
#endif

import os
@testable import Peach

struct MockAudioSessionConfigurator: AudioSessionConfiguring {
    func configure(logger: Logger) throws {}
}

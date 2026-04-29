import Foundation

extension TimingOffsetDetectionSession {
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings
    ) {
        builder.register(
            destination: .timingOffsetDetection,
            session: self
        ) {
            self.start(settings: .from(userSettings))
        }
    }
}

protocol SoundSourceProvider {
    var availableSources: [SoundSourceID] { get }
    func displayName(for source: SoundSourceID) -> String
}

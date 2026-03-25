protocol SoundSourceProvider {
    var availableSources: [any SoundSourceID] { get }
}

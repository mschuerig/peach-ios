protocol PitchMatchingProfile: AnyObject {
    func updateMatching(note: MIDINote, centError: Cents)
    var matchingMean: Cents? { get }
    var matchingStdDev: Cents? { get }
    var matchingSampleCount: Int { get }
    func resetMatching()
}

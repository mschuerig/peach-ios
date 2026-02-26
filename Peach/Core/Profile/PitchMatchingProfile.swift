protocol PitchMatchingProfile: AnyObject {
    func updateMatching(note: MIDINote, centError: Double)
    var matchingMean: Double? { get }
    var matchingStdDev: Double? { get }
    var matchingSampleCount: Int { get }
    func resetMatching()
}

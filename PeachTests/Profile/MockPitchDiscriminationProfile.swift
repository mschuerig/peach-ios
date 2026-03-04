@testable import Peach

final class MockPitchDiscriminationProfile: PitchDiscriminationProfile {
    var updateCallCount = 0
    var lastNote: MIDINote?
    var lastCentOffset: Double?
    var lastIsCorrect: Bool?
    var overallMean: Double? = nil
    var overallStdDev: Double? = nil
    var resetCallCount = 0

    private var noteStats: [Int: PerceptualNote] = [:]

    func update(note: MIDINote, centOffset: Double, isCorrect: Bool) {
        updateCallCount += 1
        lastNote = note
        lastCentOffset = centOffset
        lastIsCorrect = isCorrect
    }

    func weakSpots(count: Int) -> [MIDINote] {
        []
    }

    func statsForNote(_ note: MIDINote) -> PerceptualNote {
        noteStats[note.rawValue] ?? PerceptualNote()
    }

    func averageThreshold(noteRange: NoteRange) -> Int? {
        nil
    }

    func setDifficulty(note: MIDINote, difficulty: Double) {}

    func reset() {
        resetCallCount += 1
        noteStats = [:]
        overallMean = nil
        overallStdDev = nil
    }

    // MARK: - Test Helpers

    func setStats(for note: MIDINote, mean: Double, sampleCount: Int = 1) {
        noteStats[note.rawValue] = PerceptualNote(mean: mean, sampleCount: sampleCount)
    }
}

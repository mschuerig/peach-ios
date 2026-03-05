@testable import Peach

final class MockPitchComparisonProfile: PitchComparisonProfile {
    var updateCallCount = 0
    var lastNote: MIDINote?
    var lastCentOffset: Cents?
    var lastIsCorrect: Bool?
    var overallMean: Cents? = nil
    var overallStdDev: Cents? = nil
    var resetCallCount = 0

    private var noteStats: [Int: PerceptualNote] = [:]

    func update(note: MIDINote, centOffset: Cents, isCorrect: Bool) {
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

    func averageThreshold(noteRange: NoteRange) -> Cents? {
        nil
    }

    func setDifficulty(note: MIDINote, difficulty: Cents) {}

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

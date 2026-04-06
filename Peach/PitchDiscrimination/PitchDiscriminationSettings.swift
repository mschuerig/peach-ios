import Foundation

struct PitchDiscriminationSettings {
    var noteRange: NoteRange
    var referencePitch: Frequency
    var intervals: Set<DirectedInterval>
    var tuningSystem: TuningSystem
    var noteDuration: NoteDuration
    var varyLoudness: UnitInterval
    var minCentDifference: Cents
    var maxCentDifference: Cents
    var maxLoudnessOffsetDB: AmplitudeDB
    var velocity: MIDIVelocity
    var noteGap: Duration
    var feedbackDuration: Duration

    init(
        noteRange: NoteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)),
        referencePitch: Frequency,
        intervals: Set<DirectedInterval>,
        tuningSystem: TuningSystem = .equalTemperament,
        noteDuration: NoteDuration = NoteDuration(0.75),
        varyLoudness: UnitInterval = UnitInterval(0.0),
        minCentDifference: Cents = Cents(0.1),
        maxCentDifference: Cents = Cents(100.0),
        maxLoudnessOffsetDB: AmplitudeDB = AmplitudeDB(10.0),
        velocity: MIDIVelocity = .mezzoPiano,
        noteGap: Duration = .zero,
        feedbackDuration: Duration = .milliseconds(400)
    ) {
        self.noteRange = noteRange
        self.referencePitch = referencePitch
        self.intervals = intervals
        self.tuningSystem = tuningSystem
        self.noteDuration = noteDuration
        self.varyLoudness = varyLoudness
        self.minCentDifference = minCentDifference
        self.maxCentDifference = maxCentDifference
        self.maxLoudnessOffsetDB = maxLoudnessOffsetDB
        self.velocity = velocity
        self.noteGap = noteGap
        self.feedbackDuration = feedbackDuration
    }

    static func from(_ userSettings: UserSettings, intervals: Set<DirectedInterval>) -> PitchDiscriminationSettings {
        PitchDiscriminationSettings(
            noteRange: userSettings.noteRange,
            referencePitch: userSettings.referencePitch,
            intervals: intervals,
            tuningSystem: userSettings.tuningSystem,
            noteDuration: userSettings.noteDuration,
            varyLoudness: userSettings.varyLoudness,
            noteGap: userSettings.noteGap
        )
    }
}

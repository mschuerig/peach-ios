import Foundation

struct PitchMatchingSettings {
    var noteRange: NoteRange
    var referencePitch: Frequency
    var intervals: Set<DirectedInterval>
    var tuningSystem: TuningSystem
    var noteDuration: NoteDuration
    var varyLoudness: UnitInterval
    var maxLoudnessOffsetDB: AmplitudeDB
    var initialCentOffsetRange: ClosedRange<Cents>
    var velocity: MIDIVelocity
    var feedbackDuration: Duration

    init(
        noteRange: NoteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)),
        referencePitch: Frequency,
        intervals: Set<DirectedInterval>,
        tuningSystem: TuningSystem = .equalTemperament,
        noteDuration: NoteDuration = NoteDuration(0.75),
        varyLoudness: UnitInterval = UnitInterval(0.0),
        maxLoudnessOffsetDB: AmplitudeDB = AmplitudeDB(10.0),
        initialCentOffsetRange: ClosedRange<Cents> = Cents(-20.0)...Cents(20.0),
        velocity: MIDIVelocity = .mezzoPiano,
        feedbackDuration: Duration = .milliseconds(400)
    ) {
        self.noteRange = noteRange
        self.referencePitch = referencePitch
        self.intervals = intervals
        self.tuningSystem = tuningSystem
        self.noteDuration = noteDuration
        self.varyLoudness = varyLoudness
        self.maxLoudnessOffsetDB = maxLoudnessOffsetDB
        self.initialCentOffsetRange = initialCentOffsetRange
        self.velocity = velocity
        self.feedbackDuration = feedbackDuration
    }

    static func from(_ userSettings: UserSettings, intervals: Set<DirectedInterval>) -> PitchMatchingSettings {
        PitchMatchingSettings(
            noteRange: userSettings.noteRange,
            referencePitch: userSettings.referencePitch,
            intervals: intervals,
            tuningSystem: userSettings.tuningSystem,
            noteDuration: userSettings.noteDuration,
            varyLoudness: userSettings.varyLoudness
        )
    }
}

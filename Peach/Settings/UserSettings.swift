import Foundation

protocol UserSettings {
    var noteRange: NoteRange { get }
    var noteDuration: NoteDuration { get }
    var referencePitch: Frequency { get }
    var soundSource: String { get }
    var varyLoudness: UnitInterval { get }
    var intervals: Set<DirectedInterval> { get }
    var tuningSystem: TuningSystem { get }
    var noteGap: Duration { get }
}

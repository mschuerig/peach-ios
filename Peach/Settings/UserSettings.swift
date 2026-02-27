import Foundation

protocol UserSettings {
    var noteRangeMin: MIDINote { get }
    var noteRangeMax: MIDINote { get }
    var noteDuration: NoteDuration { get }
    var referencePitch: Frequency { get }
    var soundSource: SoundSourceID { get }
    var varyLoudness: UnitInterval { get }
    var naturalVsMechanical: Double { get }
}

import Testing
import SwiftUI
@testable import Peach

@Suite("ProfileScreen Tests")
@MainActor
struct ProfileScreenTests {

    // MARK: - PerceptualProfile Environment Key

    @Test("PerceptualProfile environment key provides default value")
    func environmentKeyDefaultValue() async throws {
        var env = EnvironmentValues()
        let profile = env.perceptualProfile
        #expect(profile.overallMean == nil)
    }

    @Test("PerceptualProfile environment key can be set and retrieved")
    func environmentKeySetAndGet() async throws {
        let profile = PerceptualProfile()
        profile.update(note: 60, centOffset: 50, isCorrect: true)

        var env = EnvironmentValues()
        env.perceptualProfile = profile

        let retrieved = env.perceptualProfile
        #expect(retrieved.statsForNote(60).mean == 50.0)
    }

    // MARK: - Piano Keyboard Layout

    @Test("Piano layout identifies white and black keys correctly")
    func pianoKeyTypes() async throws {
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 36) == true)  // C2
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 37) == false) // C#2
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 38) == true)  // D2
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 39) == false) // D#2
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 40) == true)  // E2
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 41) == true)  // F2
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 42) == false) // F#2
        #expect(PianoKeyboardLayout.isWhiteKey(midiNote: 60) == true)  // C4 (middle C)
    }

    @Test("Piano layout counts white keys in default range")
    func whiteKeyCount() async throws {
        let layout = PianoKeyboardLayout(midiRange: 36...84)
        #expect(layout.whiteKeyCount == 29)
    }

    @Test("Piano layout provides note name for octave boundaries")
    func noteNames() async throws {
        #expect(PianoKeyboardLayout.noteName(midiNote: 36) == "C2")
        #expect(PianoKeyboardLayout.noteName(midiNote: 48) == "C3")
        #expect(PianoKeyboardLayout.noteName(midiNote: 60) == "C4")
        #expect(PianoKeyboardLayout.noteName(midiNote: 72) == "C5")
        #expect(PianoKeyboardLayout.noteName(midiNote: 84) == "C6")
    }

    @Test("Piano layout X position maps MIDI notes to horizontal coordinates")
    func xPositionMapping() async throws {
        let layout = PianoKeyboardLayout(midiRange: 36...84)
        let totalWidth: CGFloat = 290

        let firstX = layout.xPosition(forMidiNote: 36, totalWidth: totalWidth)
        #expect(firstX >= 0)
        #expect(firstX < totalWidth / 2)

        let lastX = layout.xPosition(forMidiNote: 84, totalWidth: totalWidth)
        #expect(lastX > totalWidth / 2)
        #expect(lastX <= totalWidth)

        let midX = layout.xPosition(forMidiNote: 60, totalWidth: totalWidth)
        #expect(midX > firstX)
        #expect(midX < lastX)
    }
}

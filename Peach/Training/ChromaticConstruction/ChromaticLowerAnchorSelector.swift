import SwiftUI

/// Picker for the lower anchor MIDI note. Three allowed values: C3 / C4 / C5
/// (`MIDINote(48)` / `MIDINote(60)` / `MIDINote(72)`). View-local @State only;
/// no persistence in the experimental cut.
struct ChromaticLowerAnchorSelector: View {
    @Binding var anchor: MIDINote

    static let allowedAnchors: [MIDINote] = [MIDINote(48), MIDINote(60), MIDINote(72)]

    var body: some View {
        Picker(selection: $anchor) {
            ForEach(Self.allowedAnchors, id: \.self) { note in
                Text(Self.label(for: note)).tag(note)
            }
        } label: {
            Text(String(localized: "Lower anchor"))
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "Lower anchor"))
    }

    static func label(for note: MIDINote) -> String {
        switch note.rawValue {
        case 48: "C3"
        case 60: "C4"
        case 72: "C5"
        default: "\(note.rawValue)"
        }
    }
}

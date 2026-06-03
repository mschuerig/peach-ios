import SwiftUI

/// Domain-shaped Settings control for the training note range.
///
/// Renders the full 88-key piano (A0–C8) with in-range keys at full saturation,
/// out-of-range keys dimmed. Two chevron-with-pill markers above the keyboard
/// can be dragged to set the lower and upper bounds; tapping a dimmed key jumps
/// the nearer bound. The 12-semitone minimum span (`NoteRange.minimumSpan`) is
/// enforced by stopping the active marker at the limit.
///
/// Audio preview is the caller's responsibility: `onCommit` fires once on
/// drag-release / tap-extend / keyboard-arrow commit with the new `MIDINote`,
/// and the call site routes it through `SettingsCoordinator.playSoundPreview`.
///
/// At Dynamic Type sizes `>= .accessibility1`, the keyboard graphic is hidden
/// in favour of a summary line plus two adjacent system `Slider`s — see
/// `KeyboardSummary` in this file.
///
/// Sibling of ``ContinuousValueSlider`` and ``DiscreteStopsSlider``;
/// see the former's doc comment for the Epic 81 Settings control taxonomy.
struct NoteRangeSelector: View {
    @Binding var lowerBound: Int
    @Binding var upperBound: Int
    let onCommit: ((MIDINote) -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedMarker: Marker?

    init(
        lowerBound: Binding<Int>,
        upperBound: Binding<Int>,
        onCommit: ((MIDINote) -> Void)? = nil
    ) {
        self._lowerBound = lowerBound
        self._upperBound = upperBound
        self.onCommit = onCommit
    }

    enum Marker: Hashable { case lower, upper }
    enum TapOutcome: Equatable {
        case noOp
        case moveLower(MIDINote)
        case moveUpper(MIDINote)
    }

    private static let layout = PianoKeyboardLayout(
        noteRange: NoteRange(
            lowerBound: SettingsKeys.absoluteMinNote,
            upperBound: SettingsKeys.absoluteMaxNote
        )
    )
    private static let whiteKeyHeight: CGFloat = 64
    private static let blackKeyHeight: CGFloat = 40
    private static let blackKeyWidthRatio: CGFloat = 0.62
    private static let markerRowHeight: CGFloat = 30
    private static let labelRowHeight: CGFloat = 14
    private static let totalKeyboardHeight: CGFloat =
        markerRowHeight + whiteKeyHeight + labelRowHeight + 8
    private static let minKeyboardWidth: CGFloat = 416 // 52 white keys × 8 pt
    private static let keyboardCoordinateSpace = "noteRangeKeyboard"
    private static let allKeys: [MIDINote] = (
        SettingsKeys.absoluteMinNote.rawValue...SettingsKeys.absoluteMaxNote.rawValue
    ).map(MIDINote.init)
    private static let whiteKeys: [MIDINote] = allKeys.filter(PianoKeyboardLayout.isWhiteKey)
    private static let blackKeys: [MIDINote] = allKeys.filter { !PianoKeyboardLayout.isWhiteKey($0) }

    private static func clampedToAbsoluteRange(_ raw: Int) -> MIDINote {
        MIDINote(min(max(raw, SettingsKeys.absoluteMinNote.rawValue), SettingsKeys.absoluteMaxNote.rawValue))
    }

    private var lowerNote: MIDINote { Self.clampedToAbsoluteRange(lowerBound) }
    private var upperNote: MIDINote { Self.clampedToAbsoluteRange(upperBound) }

    /// Effective upper used for clamping the lower bound. Clamps `upperBound`
    /// into `[absoluteMinNote + minimumSpan, absoluteMaxNote]` so that
    /// `MIDINote(effectiveUpper - minimumSpan)` is always a valid MIDI note
    /// and the resulting `ClosedRange` is always well-formed, even when
    /// `@AppStorage` holds corrupt values written by a debugger.
    private var effectiveUpperBound: Int {
        min(
            SettingsKeys.absoluteMaxNote.rawValue,
            max(SettingsKeys.absoluteMinNote.rawValue + NoteRange.minimumSpan, upperBound)
        )
    }
    private var effectiveLowerBound: Int {
        max(
            SettingsKeys.absoluteMinNote.rawValue,
            min(SettingsKeys.absoluteMaxNote.rawValue - NoteRange.minimumSpan, lowerBound)
        )
    }
    private var lowerLegalRange: ClosedRange<MIDINote> {
        SettingsKeys.absoluteMinNote...MIDINote(effectiveUpperBound - NoteRange.minimumSpan)
    }
    private var upperLegalRange: ClosedRange<MIDINote> {
        MIDINote(effectiveLowerBound + NoteRange.minimumSpan)...SettingsKeys.absoluteMaxNote
    }

    // MARK: - Body

    var body: some View {
        if dynamicTypeSize >= .accessibility1 {
            KeyboardSummary(
                lower: lowerNote,
                upper: upperNote,
                lowerBinding: lowerSliderBinding,
                upperBinding: upperSliderBinding,
                lowerLegalRange: lowerLegalRange,
                upperLegalRange: upperLegalRange
            )
        } else {
            keyboardBody
        }
    }

    private var keyboardBody: some View {
        GeometryReader { proxy in
            let fits = Self.fitsWithoutScrolling(availableWidth: proxy.size.width)
            let totalWidth = fits ? proxy.size.width : Self.minKeyboardWidth
            Group {
                if fits {
                    keyboardStack(totalWidth: totalWidth)
                } else {
                    ScrollViewReader { scroll in
                        ScrollView(.horizontal, showsIndicators: false) {
                            keyboardStack(totalWidth: totalWidth)
                                .frame(width: totalWidth)
                        }
                        .onAppear {
                            let centre = (lowerBound + upperBound) / 2
                            scroll.scrollTo(centre, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(height: Self.totalKeyboardHeight)
        .accessibilityElement(children: .contain)
        .accessibilityRepresentation {
            VStack {
                Slider(value: lowerSliderBinding, in: sliderRange(lowerLegalRange), step: 1) {
                    Text("Lowest Note", comment: "Accessibility label for the lower-bound marker on the Training Range piano-keyboard control.")
                }
                .accessibilityValue(Text(lowerNote.name))
                Slider(value: upperSliderBinding, in: sliderRange(upperLegalRange), step: 1) {
                    Text("Highest Note", comment: "Accessibility label for the upper-bound marker on the Training Range piano-keyboard control.")
                }
                .accessibilityValue(Text(upperNote.name))
            }
        }
    }

    private func keyboardStack(totalWidth: CGFloat) -> some View {
        VStack(spacing: 4) {
            markerRow(totalWidth: totalWidth)
            keysRow(totalWidth: totalWidth)
            labelsRow(totalWidth: totalWidth)
        }
        .frame(width: totalWidth)
        .coordinateSpace(.named(Self.keyboardCoordinateSpace))
    }

    // MARK: - Marker row

    private func markerRow(totalWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: totalWidth, height: Self.markerRowHeight)
            BoundMarker(note: lowerNote)
                .position(x: Self.layout.xPosition(forNote: lowerNote, totalWidth: totalWidth), y: Self.markerRowHeight / 2)
                .gesture(dragGesture(for: .lower, totalWidth: totalWidth))
                .focusable()
                .focused($focusedMarker, equals: .lower)
                .onKeyPress(phases: [.down, .repeat]) { press in
                    handleKey(press, marker: .lower)
                }
                .accessibilityHint(Text("Drag to set the lowest training note", comment: "Accessibility hint for the draggable lower-bound marker on the Training Range piano-keyboard control."))
            BoundMarker(note: upperNote)
                .position(x: Self.layout.xPosition(forNote: upperNote, totalWidth: totalWidth), y: Self.markerRowHeight / 2)
                .gesture(dragGesture(for: .upper, totalWidth: totalWidth))
                .focusable()
                .focused($focusedMarker, equals: .upper)
                .onKeyPress(phases: [.down, .repeat]) { press in
                    handleKey(press, marker: .upper)
                }
                .accessibilityHint(Text("Drag to set the highest training note", comment: "Accessibility hint for the draggable upper-bound marker on the Training Range piano-keyboard control."))
        }
        .frame(width: totalWidth, height: Self.markerRowHeight)
    }

    // MARK: - Keys row

    private func keysRow(totalWidth: CGFloat) -> some View {
        let keyWidth = Self.layout.whiteKeyWidth(totalWidth: totalWidth)
        let blackWidth = keyWidth * Self.blackKeyWidthRatio
        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(Self.whiteKeys, id: \.rawValue) { note in
                    PianoKey(note: note, isWhite: true, isInRange: isInRange(note))
                        .frame(width: keyWidth, height: Self.whiteKeyHeight)
                        .id(note.rawValue)
                }
            }
            ForEach(Self.blackKeys, id: \.rawValue) { note in
                let x = Self.layout.xPosition(forNote: note, totalWidth: totalWidth)
                PianoKey(note: note, isWhite: false, isInRange: isInRange(note))
                    .frame(width: blackWidth, height: Self.blackKeyHeight)
                    .position(x: x, y: Self.blackKeyHeight / 2)
                    .id(note.rawValue)
            }
        }
        .frame(width: totalWidth, height: Self.whiteKeyHeight, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .named(Self.keyboardCoordinateSpace)) { location in
            handleTap(location: location, totalWidth: totalWidth)
        }
    }

    // MARK: - Octave labels row

    private func labelsRow(totalWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: totalWidth, height: Self.labelRowHeight)
            ForEach(Self.layout.octaveBoundaries, id: \.rawValue) { note in
                Text(note.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    .position(
                        x: Self.layout.xPosition(forNote: note, totalWidth: totalWidth),
                        y: Self.labelRowHeight / 2
                    )
            }
        }
        .frame(width: totalWidth, height: Self.labelRowHeight)
    }

    // MARK: - Gesture / tap / key handlers

    private func dragGesture(for marker: Marker, totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.keyboardCoordinateSpace))
            .onChanged { value in
                applyDrag(marker: marker, location: value.location, totalWidth: totalWidth, commit: false)
            }
            .onEnded { value in
                applyDrag(marker: marker, location: value.location, totalWidth: totalWidth, commit: true)
            }
    }

    private func applyDrag(marker: Marker, location: CGPoint, totalWidth: CGFloat, commit: Bool) {
        let raw = Self.layout.midiNote(at: location.x, totalWidth: totalWidth)
        switch marker {
        case .lower:
            let clamped = Self.clampedToAbsoluteRange(Self.clampLower(raw, against: upperNote).rawValue)
            if clamped.rawValue != lowerBound {
                lowerBound = clamped.rawValue
            }
            if commit { onCommit?(clamped) }
        case .upper:
            let clamped = Self.clampedToAbsoluteRange(Self.clampUpper(raw, against: lowerNote).rawValue)
            if clamped.rawValue != upperBound {
                upperBound = clamped.rawValue
            }
            if commit { onCommit?(clamped) }
        }
    }

    private func handleTap(location: CGPoint, totalWidth: CGFloat) {
        let tapped = Self.layout.midiNote(at: location.x, totalWidth: totalWidth)
        switch Self.tapResolution(at: tapped, lower: lowerNote, upper: upperNote) {
        case .noOp:
            return
        case .moveLower(let note):
            let clamped = Self.clampedToAbsoluteRange(Self.clampLower(note, against: upperNote).rawValue)
            lowerBound = clamped.rawValue
            onCommit?(clamped)
        case .moveUpper(let note):
            let clamped = Self.clampedToAbsoluteRange(Self.clampUpper(note, against: lowerNote).rawValue)
            upperBound = clamped.rawValue
            onCommit?(clamped)
        }
    }

    private func handleKey(_ press: KeyPress, marker: Marker) -> KeyPress.Result {
        let current: MIDINote
        let legalRange: ClosedRange<MIDINote>
        switch marker {
        case .lower:
            current = lowerNote
            legalRange = lowerLegalRange
        case .upper:
            current = upperNote
            legalRange = upperLegalRange
        }
        guard let next = Self.keyboardCommit(
            press.key,
            modifiers: press.modifiers,
            current: current,
            legalRange: legalRange
        ) else {
            return .ignored
        }
        switch marker {
        case .lower: lowerBound = next.rawValue
        case .upper: upperBound = next.rawValue
        }
        onCommit?(next)
        return .handled
    }

    // MARK: - Slider-binding bridges for the accessibilityRepresentation

    private var lowerSliderBinding: Binding<Double> {
        Binding(
            get: { Double(lowerNote.rawValue) },
            set: { newValue in
                let candidate = Self.clampedToAbsoluteRange(Int(newValue.rounded()))
                let clamped = Self.clampLower(candidate, against: upperNote)
                if clamped.rawValue != lowerBound {
                    lowerBound = clamped.rawValue
                    onCommit?(clamped)
                }
            }
        )
    }

    private var upperSliderBinding: Binding<Double> {
        Binding(
            get: { Double(upperNote.rawValue) },
            set: { newValue in
                let candidate = Self.clampedToAbsoluteRange(Int(newValue.rounded()))
                let clamped = Self.clampUpper(candidate, against: lowerNote)
                if clamped.rawValue != upperBound {
                    upperBound = clamped.rawValue
                    onCommit?(clamped)
                }
            }
        )
    }

    private func sliderRange(_ range: ClosedRange<MIDINote>) -> ClosedRange<Double> {
        Double(range.lowerBound.rawValue)...Double(range.upperBound.rawValue)
    }

    private func isInRange(_ note: MIDINote) -> Bool {
        note.rawValue >= lowerBound && note.rawValue <= upperBound
    }

    // MARK: - Static logic helpers (testable without SwiftUI)

    static func clampLower(
        _ candidate: MIDINote,
        against upper: MIDINote,
        minimumSpan: Int = NoteRange.minimumSpan
    ) -> MIDINote {
        let rawCeiling = upper.rawValue - minimumSpan
        let ceiling = max(MIDINote.validRange.lowerBound, min(MIDINote.validRange.upperBound, rawCeiling))
        return MIDINote(min(candidate.rawValue, ceiling))
    }

    static func clampUpper(
        _ candidate: MIDINote,
        against lower: MIDINote,
        minimumSpan: Int = NoteRange.minimumSpan
    ) -> MIDINote {
        let rawFloor = lower.rawValue + minimumSpan
        let floor = min(MIDINote.validRange.upperBound, max(MIDINote.validRange.lowerBound, rawFloor))
        return MIDINote(max(candidate.rawValue, floor))
    }

    static func tapResolution(at tapped: MIDINote, lower: MIDINote, upper: MIDINote) -> TapOutcome {
        if tapped >= lower && tapped <= upper { return .noOp }
        let distanceToLower = abs(tapped.rawValue - lower.rawValue)
        let distanceToUpper = abs(tapped.rawValue - upper.rawValue)
        if distanceToLower <= distanceToUpper {
            return .moveLower(tapped)
        }
        return .moveUpper(tapped)
    }

    static func keyboardCommit(
        _ key: KeyEquivalent,
        modifiers: EventModifiers,
        current: MIDINote,
        legalRange: ClosedRange<MIDINote>
    ) -> MIDINote? {
        let candidateRaw: Int
        switch key {
        case .leftArrow:
            candidateRaw = current.rawValue - (modifiers.contains(.shift) ? 12 : 1)
        case .rightArrow:
            candidateRaw = current.rawValue + (modifiers.contains(.shift) ? 12 : 1)
        case .home:
            candidateRaw = legalRange.lowerBound.rawValue
        case .end:
            candidateRaw = legalRange.upperBound.rawValue
        default:
            return nil
        }
        let clampedRaw = min(max(candidateRaw, legalRange.lowerBound.rawValue), legalRange.upperBound.rawValue)
        if clampedRaw == current.rawValue { return nil }
        return MIDINote(clampedRaw)
    }

    static func fitsWithoutScrolling(
        availableWidth: CGFloat,
        whiteKeyCount: Int = 52,
        minWhiteKeyWidth: CGFloat = 8
    ) -> Bool {
        availableWidth >= CGFloat(whiteKeyCount) * minWhiteKeyWidth
    }

    static func summaryLine(lower: MIDINote, upper: MIDINote, locale: Locale = .current) -> String {
        String(
            localized: "Lowest \(lower.name) · Highest \(upper.name)",
            locale: locale,
            comment: "AX1+ summary line for the Training Range piano-keyboard control. Placeholders are MIDI note names like \"C2\" and \"C6\"."
        )
    }
}

// MARK: - Private subviews

private struct PianoKey: View {
    let note: MIDINote
    let isWhite: Bool
    let isInRange: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
            )
            .opacity(isInRange ? 1.0 : 0.35)
            .accessibilityLabel(Text(note.name))
    }

    private var fillColor: Color {
        isWhite ? Color(white: 0.97) : Color(white: 0.15)
    }
}

private struct BoundMarker: View {
    let note: MIDINote

    var body: some View {
        VStack(spacing: 0) {
            Text(note.name)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
                .offset(y: -2)
        }
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

private struct KeyboardSummary: View {
    let lower: MIDINote
    let upper: MIDINote
    let lowerBinding: Binding<Double>
    let upperBinding: Binding<Double>
    let lowerLegalRange: ClosedRange<MIDINote>
    let upperLegalRange: ClosedRange<MIDINote>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NoteRangeSelector.summaryLine(lower: lower, upper: upper))
                .font(.body)
                .accessibilityHidden(true)
            Slider(
                value: lowerBinding,
                in: Double(lowerLegalRange.lowerBound.rawValue)...Double(lowerLegalRange.upperBound.rawValue),
                step: 1
            ) {
                Text("Lowest Note", comment: "Accessibility label for the lower-bound slider in the Training Range AX1+ fallback.")
            }
            .accessibilityValue(Text(lower.name))
            Slider(
                value: upperBinding,
                in: Double(upperLegalRange.lowerBound.rawValue)...Double(upperLegalRange.upperBound.rawValue),
                step: 1
            ) {
                Text("Highest Note", comment: "Accessibility label for the upper-bound slider in the Training Range AX1+ fallback.")
            }
            .accessibilityValue(Text(upper.name))
        }
    }
}

#if DEBUG
#Preview("NoteRangeSelector") {
    @Previewable @State var low: Int = 36
    @Previewable @State var high: Int = 84
    return Form {
        Section("Training Range") {
            NoteRangeSelector(lowerBound: $low, upperBound: $high)
        }
    }
}
#endif

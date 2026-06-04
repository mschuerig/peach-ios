import SwiftUI

/// A continuous-value slider for Settings rows.
///
/// Renders as a `VStack`: row 1 shows `label` on the left and the live
/// `displayFormat(value)` on the right in monospaced digits; row 2 shows a
/// flanking `−` button, a `Slider(value:, in:, step:)`, and a `+` button.
/// The `−` and `+` buttons increment/decrement by `step` and clamp at the
/// range bounds; each one disables itself when the value reaches its bound.
///
/// # Settings Control Taxonomy (Epic 81)
///
/// When adding a new Settings row, pick the control that matches the *kind*
/// of value being set, not the one most recently added:
///
/// | Kind of value                                          | Control                            | Today                                |
/// |--------------------------------------------------------|------------------------------------|--------------------------------------|
/// | Continuous / perceptual ("feel for the right setting") | `ContinuousValueSlider`            | Note Duration, Note Gap, Tempo       |
/// | Abstract dimensionless dial (no specific number matters)| `Slider` with min/max end labels  | Vary Loudness                        |
/// | Bounded range inside a fixed domain                    | Domain-shaped custom control       | Piano keyboard for MIDI notes (81.3) |
/// | Small enumerated set with semantic differences         | Custom row (tiles or discrete-stops)| TOD Max Repetitions, Intervals, Gap Positions |
/// | Large enumerated set                                   | `Picker`                           | Sound Source, Tuning System          |
/// | Precise value where ±1 matters more than feel          | `Stepper`                          | Concert Pitch                        |
///
/// Two controls intentionally do not migrate to this view:
/// - **Concert Pitch** keeps `Stepper` — the value has named landmarks
///   (415 / 432 / 440 / 442 Hz); drag would be a regression.
/// - **Vary Loudness** keeps the abstract-dial `Slider` — no specific number
///   matters, only the off↔max position.
struct ContinuousValueSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let label: LocalizedStringKey
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride
    let displayFormat: (Value) -> String
    let accessibilityFormat: (Value) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .accessibilityHidden(true)
                Spacer()
                Text(displayFormat(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 8) {
                Button {
                    value = Self.decrement(value, by: step, in: range)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .disabled(!Self.isDecrementEnabled(at: value, in: range))
                .accessibilityLabel(Text("Decrease \(Text(label))", comment: "Accessibility label for the minus precision button next to a continuous-value slider in Settings. The placeholder is the row label, e.g. \"Duration\"."))
                .accessibilityHint(Text("Decreases by \(displayFormat(Value(step)))", comment: "Accessibility hint for the minus precision button next to a continuous-value slider in Settings. The placeholder is the formatted step, e.g. \"0.1 s\" or \"1 BPM\"."))

                Slider(value: $value, in: range, step: step) {
                    Text(label)
                }
                .accessibilityValue(Text(accessibilityFormat(value)))

                Button {
                    value = Self.increment(value, by: step, in: range)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .disabled(!Self.isIncrementEnabled(at: value, in: range))
                .accessibilityLabel(Text("Increase \(Text(label))", comment: "Accessibility label for the plus precision button next to a continuous-value slider in Settings. The placeholder is the row label, e.g. \"Duration\"."))
                .accessibilityHint(Text("Increases by \(displayFormat(Value(step)))", comment: "Accessibility hint for the plus precision button next to a continuous-value slider in Settings. The placeholder is the formatted step, e.g. \"0.1 s\" or \"1 BPM\"."))
            }
        }
    }

    // MARK: - Static Logic Helpers

    static func increment(_ value: Value, by step: Value.Stride, in range: ClosedRange<Value>) -> Value {
        min(range.upperBound, value + Value(step))
    }

    static func decrement(_ value: Value, by step: Value.Stride, in range: ClosedRange<Value>) -> Value {
        max(range.lowerBound, value - Value(step))
    }

    static func isIncrementEnabled(at value: Value, in range: ClosedRange<Value>) -> Bool {
        value < range.upperBound
    }

    static func isDecrementEnabled(at value: Value, in range: ClosedRange<Value>) -> Bool {
        value > range.lowerBound
    }
}

// MARK: - Format Helpers for the Three Settings Migrations

extension ContinuousValueSlider where Value == Double {
    /// One-decimal-with-locale-separator + ` s` suffix. Used by Note Duration and Note Gap.
    static func displayDuration(_ value: Double, locale: Locale = .current) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)).locale(locale))) s"
    }

    /// Integer + ` BPM` suffix. Used by Rhythm Tempo. Integer formatting is
    /// locale-independent so no locale argument is needed.
    static func displayTempo(_ value: Double) -> String {
        "\(Int(value.rounded())) BPM"
    }

    /// Localised "1.2 seconds" / "1,2 Sekunden". Used by Note Duration and Note Gap.
    static func accessibilityDuration(_ value: Double, locale: Locale = .current) -> String {
        String(
            localized: "\(value.formatted(.number.precision(.fractionLength(1)).locale(locale))) seconds",
            locale: locale,
            comment: "Accessibility value for a duration slider in Settings. The placeholder is a formatted decimal number."
        )
    }

    /// Localised "120 beats per minute" / "120 Schläge pro Minute". Used by Rhythm Tempo.
    static func accessibilityTempo(_ value: Double, locale: Locale = .current) -> String {
        String(
            localized: "\(Int(value.rounded())) beats per minute",
            locale: locale,
            comment: "Accessibility value for the rhythm tempo slider in Settings. The placeholder is an integer BPM value."
        )
    }
}

#if DEBUG
#Preview("Duration") {
    @Previewable @State var duration: Double = 1.0
    return Form {
        ContinuousValueSlider(
            label: "Duration",
            value: $duration,
            range: 0.3...3.0,
            step: 0.1,
            displayFormat: { ContinuousValueSlider.displayDuration($0) },
            accessibilityFormat: { ContinuousValueSlider.accessibilityDuration($0) }
        )
    }
}

#Preview("Tempo") {
    @Previewable @State var tempo: Double = 80
    return Form {
        ContinuousValueSlider(
            label: "Tempo",
            value: $tempo,
            range: 40...200,
            step: 1,
            displayFormat: ContinuousValueSlider.displayTempo,
            accessibilityFormat: { ContinuousValueSlider.accessibilityTempo($0) }
        )
    }
}
#endif

import SwiftUI

/// A discrete-stops sibling of ``ContinuousValueSlider`` for Settings rows
/// whose underlying value is one of a small, ordered, non-linearly spaced
/// set of integers (e.g. `[1, 2, 3, 5, 10, ∞]` for TOD Maximum Repetitions).
///
/// Renders as a `VStack`: row 1 shows `label` on the left and the live
/// `displayFormat(value)` on the right in monospaced digits; row 2 shows a
/// flanking `−` button, a `Slider` over the stop *index*, and a `+` button,
/// with thin tick-mark rectangles overlaid at each stop position. The slider
/// snaps to a stop on drag-release; `−` / `+` step to the adjacent stop.
///
/// See ``ContinuousValueSlider`` for the full Settings control taxonomy. This
/// view is the "small enumerated set with semantic differences" idiom in
/// slider form.
struct DiscreteStopsSlider: View {
    let label: LocalizedStringKey
    @Binding var value: Int
    /// Must be sorted ascending. Precondition is not enforced at runtime — the
    /// single call site complies.
    let stops: [Int]
    let displayFormat: (Int) -> String
    let accessibilityFormat: (Int) -> String

    var body: some View {
        // Display the value at the snapped stop, not the raw stored value.
        // For in-set values these are identical; for an out-of-set stored
        // value (e.g. a debugger write of 7 against stops [1,2,3,5,10,20])
        // the right-side readout and the slider thumb stay in sync.
        let snapped = stops.isEmpty ? value : stops[Self.nearestStopIndex(to: value, in: stops)]
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .accessibilityHidden(true)
                Spacer()
                Text(displayFormat(snapped))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 8) {
                Button {
                    value = Self.decrementValue(value, in: stops)
                } label: {
                    Image(systemName: "minus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!Self.isDecrementEnabled(at: value, in: stops))
                .accessibilityLabel(Text("Decrease \(Text(label))", comment: "Accessibility label for the minus precision button next to a discrete-stops slider in Settings. The placeholder is the row label, e.g. \"Maximum Repetitions\"."))
                .accessibilityHint(Text("Selects the next lower value", comment: "Accessibility hint for the minus precision button next to a discrete-stops slider in Settings. The per-step magnitude varies between stops, so the hint is step-agnostic."))

                Slider(value: Self.indexBinding($value, in: stops), in: 0...Double(max(stops.count - 1, 0)), step: 1) {
                    Text(label)
                }
                .accessibilityValue(Text(accessibilityFormat(snapped)))
                .overlay(alignment: .center) {
                    TickMarks(count: stops.count)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                Button {
                    value = Self.incrementValue(value, in: stops)
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!Self.isIncrementEnabled(at: value, in: stops))
                .accessibilityLabel(Text("Increase \(Text(label))", comment: "Accessibility label for the plus precision button next to a discrete-stops slider in Settings. The placeholder is the row label, e.g. \"Maximum Repetitions\"."))
                .accessibilityHint(Text("Selects the next higher value", comment: "Accessibility hint for the plus precision button next to a discrete-stops slider in Settings. The per-step magnitude varies between stops, so the hint is step-agnostic."))
            }
        }
    }

    // MARK: - Static Logic Helpers

    /// Adapts the outer `Binding<Int>` (a stop value) to a `Binding<Double>`
    /// (a slider index). On get, looks up the index of the nearest stop. On
    /// set, snaps the incoming Double index to the closest valid integer and
    /// writes the corresponding stop value.
    static func indexBinding(_ value: Binding<Int>, in stops: [Int]) -> Binding<Double> {
        Binding(
            get: { Double(nearestStopIndex(to: value.wrappedValue, in: stops)) },
            set: { newIndex in
                guard !stops.isEmpty else { return }
                let clamped = max(0, min(stops.count - 1, Int(newIndex.rounded())))
                value.wrappedValue = stops[clamped]
            }
        )
    }

    /// Returns the index in `stops` whose value is closest to `value`.
    /// Ties resolve to the higher index for consistency with the default-at-cap
    /// shape (e.g. TOD's default is the `∞` cap at the rightmost index).
    static func nearestStopIndex(to value: Int, in stops: [Int]) -> Int {
        guard !stops.isEmpty else { return 0 }
        var bestIndex = 0
        var bestDistance = abs(stops[0] - value)
        for index in 1..<stops.count {
            let distance = abs(stops[index] - value)
            if distance <= bestDistance {
                bestIndex = index
                bestDistance = distance
            }
        }
        return bestIndex
    }

    static func incrementValue(_ value: Int, in stops: [Int]) -> Int {
        guard !stops.isEmpty else { return value }
        let current = nearestStopIndex(to: value, in: stops)
        return stops[min(current + 1, stops.count - 1)]
    }

    static func decrementValue(_ value: Int, in stops: [Int]) -> Int {
        guard !stops.isEmpty else { return value }
        let current = nearestStopIndex(to: value, in: stops)
        return stops[max(current - 1, 0)]
    }

    static func isIncrementEnabled(at value: Int, in stops: [Int]) -> Bool {
        guard !stops.isEmpty else { return false }
        return nearestStopIndex(to: value, in: stops) < stops.count - 1
    }

    static func isDecrementEnabled(at value: Int, in stops: [Int]) -> Bool {
        guard !stops.isEmpty else { return false }
        return nearestStopIndex(to: value, in: stops) > 0
    }

    // MARK: - Format Helpers for TOD Maximum Repetitions

    /// Visual value: digits for integer stops, `∞` glyph at the cap. The cap
    /// value is parameterised so the helper has no hard-coded TOD coupling.
    static func displayMaxRepetitions(_ value: Int, capValue: Int) -> String {
        value == capValue ? "∞" : "\(value)"
    }

    /// VoiceOver value: digits for integer stops, the localised `"unlimited"`
    /// vocabulary at the cap. The `locale:` parameter is injectable for tests
    /// (number formatting is locale-deterministic; the bundle-language
    /// resolution for `String(localized:)` follows the running simulator —
    /// see the 81.1 Spec Change Log for the rationale).
    static func accessibilityMaxRepetitions(_ value: Int, capValue: Int, locale: Locale = .current) -> String {
        if value == capValue {
            return String(
                localized: "unlimited",
                locale: locale,
                comment: "Accessibility value for the Maximum Repetitions slider when set to the unlimited cap (rendered visually as ∞). German: \"unbegrenzt\"."
            )
        }
        return "\(value)"
    }
}

// MARK: - Tick-Mark Overlay

private struct TickMarks: View {
    let count: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ForEach(0..<count, id: \.self) { index in
                    Rectangle()
                        .fill(.tertiary)
                        .frame(width: 1, height: 6)
                        .offset(x: tickOffset(forIndex: index, totalWidth: proxy.size.width))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    /// Approximate alignment with the system slider's snap positions: the
    /// thumb has an internal radius padding that is not part of the public
    /// SwiftUI API. The pattern below distributes ticks across the slider's
    /// usable width minus an approximate thumb-radius inset on each side, so
    /// the leftmost and rightmost ticks sit roughly under the thumb at the
    /// extremes. Exact pixel alignment is intentionally not pursued.
    private func tickOffset(forIndex index: Int, totalWidth: CGFloat) -> CGFloat {
        guard count > 1 else { return totalWidth / 2 }
        let thumbInset: CGFloat = 12
        let trackWidth = max(0, totalWidth - thumbInset * 2)
        let stride = trackWidth / CGFloat(count - 1)
        return thumbInset + stride * CGFloat(index)
    }
}

#if DEBUG
#Preview("Maximum Repetitions") {
    @Previewable @State var maxRepetitions: Int = 20
    let stops: [Int] = [1, 2, 3, 5, 10, 20]
    return Form {
        DiscreteStopsSlider(
            label: "Maximum Repetitions",
            value: $maxRepetitions,
            stops: stops,
            displayFormat: { DiscreteStopsSlider.displayMaxRepetitions($0, capValue: 20) },
            accessibilityFormat: { DiscreteStopsSlider.accessibilityMaxRepetitions($0, capValue: 20) }
        )
    }
}
#endif

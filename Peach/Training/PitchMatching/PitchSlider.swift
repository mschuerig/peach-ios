import SwiftUI

struct PitchSlider: View {

    /// Whether the slider is horizontal (landscape) or vertical (portrait)
    var isHorizontal: Bool

    /// Whether the slider responds to touch (active during `playingTunable`)
    var isActive: Bool

    /// Called continuously during drag with the current value in -1.0...1.0
    var onValueChange: (Double) -> Void

    /// Called when the user releases the slider with the final value
    var onCommit: (Double) -> Void

    /// When non-nil, drives the slider thumb position externally (e.g., from MIDI pitch bend).
    /// Touch input still works as fallback when nil.
    var externalValue: Double? = nil

    // MARK: - Internal State

    @State private var currentValue: Double = 0

    // MARK: - Layout Constants

    private static let thumbDiameter: CGFloat = 70

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let trackLength = isHorizontal ? geometry.size.width : geometry.size.height

            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())

                // Range indicator line
                Capsule()
                    .fill(.separator)
                    .frame(
                        width: isHorizontal ? nil : 2,
                        height: isHorizontal ? 2 : nil
                    )

                // Thumb handle
                Circle()
                    .fill(.tint)
                    .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
                    .position(
                        x: isHorizontal
                            ? Self.thumbPosition(value: externalValue ?? currentValue, trackLength: trackLength, isHorizontal: true)
                            : geometry.size.width / 2,
                        y: isHorizontal
                            ? geometry.size.height / 2
                            : Self.thumbPosition(value: externalValue ?? currentValue, trackLength: trackLength, isHorizontal: false)
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        guard isActive else { return }
                        let dragPosition = isHorizontal ? dragValue.location.x : dragValue.location.y
                        let normalized = Self.value(dragPosition: dragPosition, trackLength: trackLength, isHorizontal: isHorizontal)
                        currentValue = normalized
                        onValueChange(normalized)
                    }
                    .onEnded { dragValue in
                        guard isActive else { return }
                        let dragPosition = isHorizontal ? dragValue.location.x : dragValue.location.y
                        let normalized = Self.value(dragPosition: dragPosition, trackLength: trackLength, isHorizontal: isHorizontal)
                        currentValue = normalized
                        onCommit(normalized)
                    }
            )
            .disabled(!isActive)
            .opacity(isActive ? 1.0 : 0.4)
        }
        .accessibilityLabel(String(localized: "Pitch adjustment slider"))
        .accessibilityValue("\(Int(currentValue * 100))%")
        .accessibilityAdjustableAction { direction in
            guard isActive else { return }
            let step = 0.1
            switch direction {
            case .increment:
                currentValue = min(1.0, currentValue + step)
            case .decrement:
                currentValue = max(-1.0, currentValue - step)
            @unknown default:
                break
            }
            onValueChange(currentValue)
        }
        .accessibilityAction(named: String(localized: "Submit pitch")) {
            guard isActive else { return }
            onCommit(currentValue)
        }
        .onChange(of: isActive) { oldValue, newValue in
            if !oldValue && newValue {
                currentValue = 0
            }
        }
        .onChange(of: externalValue) { oldValue, newValue in
            if oldValue != nil, newValue == nil, let oldValue {
                currentValue = oldValue
            }
        }
    }

    // MARK: - Static Calculation Methods (testable)

    /// Maps a drag position to a value in -1.0...1.0.
    ///
    /// Vertical: top = +1.0 (sharper), bottom = -1.0 (flatter).
    /// Horizontal: right = +1.0 (sharper), left = -1.0 (flatter).
    static func value(dragPosition: CGFloat, trackLength: CGFloat, isHorizontal: Bool) -> Double {
        guard trackLength > 0 else { return 0 }
        let fraction = dragPosition / trackLength
        let clamped = min(1.0, max(0.0, fraction))
        if isHorizontal {
            return 2.0 * clamped - 1.0
        } else {
            return 1.0 - 2.0 * clamped
        }
    }

    /// Computes the position of the thumb for a given value.
    ///
    /// Inverse of `value(dragPosition:trackLength:isHorizontal:)`.
    static func thumbPosition(value: Double, trackLength: CGFloat, isHorizontal: Bool) -> CGFloat {
        if isHorizontal {
            let fraction = (value + 1.0) / 2.0
            return trackLength * CGFloat(fraction)
        } else {
            let fraction = (1.0 - value) / 2.0
            return trackLength * CGFloat(fraction)
        }
    }
}

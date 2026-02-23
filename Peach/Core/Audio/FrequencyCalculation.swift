import Foundation

/// Utilities for converting musical note information to frequencies.
///
/// # Settings Integration (Epic 6)
///
/// The reference pitch parameter enables configurable tuning standards. In Epic 6, the Settings
/// screen will expose a reference pitch preference (stored in @AppStorage). TrainingSession will
/// read this value and pass it to FrequencyCalculation.frequency(referencePitch:) when calculating
/// note frequencies.
///
/// Example future integration:
/// ```swift
/// @AppStorage("referencePitch") private var referencePitch: Double = 440.0
///
/// func calculateFrequency(midiNote: Int, cents: Double) throws -> Double {
///     return try FrequencyCalculation.frequency(midiNote: midiNote, cents: cents, referencePitch: referencePitch)
/// }
/// ```
public enum FrequencyCalculation {
    /// Converts a MIDI note number and cent offset to a frequency in Hz.
    ///
    /// Uses the equal temperament formula:
    /// `f = referencePitch * 2^((midiNote - 69) / 12) * 2^(cents / 1200)`
    ///
    /// The reference pitch parameter allows supporting different tuning standards:
    /// - **A440 (default)**: Modern standard tuning (440 Hz)
    /// - **A442**: Baroque/orchestral tuning (442 Hz) - brighter sound
    /// - **A432**: Alternative tuning (432 Hz) - "natural frequency"
    /// - **A415**: Historical baroque tuning (415 Hz) - one semitone below A440
    ///
    /// - Parameters:
    ///   - midiNote: MIDI note number (0-127, where 69 = A4)
    ///   - cents: Cent offset from the MIDI note (-100 to +100 typical range)
    ///   - referencePitch: Reference pitch for A4 in Hz (400-500 Hz, default: 440.0)
    /// - Returns: Frequency in Hz with 0.1 cent precision
    ///
    /// # Examples
    /// ```swift
    /// // Standard tuning (A440)
    /// let c4 = FrequencyCalculation.frequency(midiNote: 60) // 261.626 Hz
    /// let a4 = FrequencyCalculation.frequency(midiNote: 69) // 440.000 Hz
    ///
    /// // Baroque tuning (A442)
    /// let a4_baroque = FrequencyCalculation.frequency(midiNote: 69, referencePitch: 442.0) // 442.000 Hz
    ///
    /// // Alternative tuning (A432)
    /// let a4_alt = FrequencyCalculation.frequency(midiNote: 69, referencePitch: 432.0) // 432.000 Hz
    ///
    /// // With cent offset
    /// let sharpC4 = FrequencyCalculation.frequency(midiNote: 60, cents: 50.0) // ~268.9 Hz (halfway to C#)
    ///
    /// // Custom reference pitch with cent offset
    /// let freq = FrequencyCalculation.frequency(midiNote: 60, cents: 25.0, referencePitch: 442.0)
    /// ```
    ///
    /// - Precondition: midiNote must be in range 0-127
    /// - Throws: `AudioError.invalidFrequency` if referencePitch is outside reasonable range (380-500 Hz)
    public static func frequency(midiNote: Int, cents: Double = 0.0, referencePitch: Double = 440.0) throws -> Double {
        precondition(midiNote >= 0 && midiNote <= 127, "MIDI note must be in range 0-127, got \(midiNote)")

        // Validate reference pitch (380-500 Hz covers all common standards including A415)
        guard (380.0...500.0).contains(referencePitch) else {
            throw AudioError.invalidFrequency(
                "Reference pitch \(referencePitch) Hz is outside reasonable range 380-500 Hz. Common standards: A415 (baroque), A432 (alternative), A440 (standard), A442 (orchestral)"
            )
        }

        let semitonesFromA4 = Double(midiNote - 69)
        let octaveOffset = semitonesFromA4 / 12.0
        let centOffset = cents / 1200.0

        return referencePitch * pow(2.0, octaveOffset) * pow(2.0, centOffset)
    }

    /// Converts a frequency in Hz to the nearest MIDI note number and cent remainder.
    ///
    /// Uses the inverse equal temperament formula:
    /// `exactMidi = 69 + 12 * log2(frequency / referencePitch)`
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz (must be positive)
    ///   - referencePitch: Reference pitch for A4 in Hz (default: 440.0)
    /// - Returns: A tuple of `(midiNote: Int, cents: Double)` where cents is in the range -50...+50
    public static func midiNoteAndCents(frequency: Double, referencePitch: Double = 440.0) -> (midiNote: Int, cents: Double) {
        let exactMidi = 69.0 + 12.0 * log2(frequency / referencePitch)
        let nearestMidi = Int((exactMidi).rounded())
        let cents = (exactMidi - Double(nearestMidi)) * 100.0
        return (midiNote: nearestMidi, cents: cents)
    }
}

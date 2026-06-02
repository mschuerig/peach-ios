import Testing
import Foundation
@testable import Peach

@Suite("ContinuousValueSlider")
struct ContinuousValueSliderTests {

    private static let enUS = Locale(identifier: "en_US")
    private static let deDE = Locale(identifier: "de_DE")

    // MARK: - Display Format

    @Test("displayDuration formats one decimal with ` s` suffix under English locale")
    func displayDurationFormatsOneDecimalEnglish() async {
        #expect(ContinuousValueSlider<Double>.displayDuration(1.2, locale: Self.enUS) == "1.2 s")
        #expect(ContinuousValueSlider<Double>.displayDuration(0.3, locale: Self.enUS) == "0.3 s")
        #expect(ContinuousValueSlider<Double>.displayDuration(3.0, locale: Self.enUS) == "3.0 s")
    }

    @Test("displayDuration formats one decimal with ` s` suffix under German locale")
    func displayDurationFormatsOneDecimalGerman() async {
        #expect(ContinuousValueSlider<Double>.displayDuration(1.2, locale: Self.deDE) == "1,2 s")
        #expect(ContinuousValueSlider<Double>.displayDuration(0.3, locale: Self.deDE) == "0,3 s")
        #expect(ContinuousValueSlider<Double>.displayDuration(3.0, locale: Self.deDE) == "3,0 s")
    }

    @Test("displayTempo rounds to integer with ` BPM` suffix")
    func displayTempoFormatsInteger() async {
        #expect(ContinuousValueSlider<Double>.displayTempo(80) == "80 BPM")
        #expect(ContinuousValueSlider<Double>.displayTempo(120.4) == "120 BPM")
        #expect(ContinuousValueSlider<Double>.displayTempo(199.6) == "200 BPM")
    }

    // MARK: - Accessibility Format

    // Notes on accessibility-helper tests:
    // - The `locale:` parameter to `String(localized:)` reliably influences
    //   the NUMBER formatting (decimal separator, grouping) but not the
    //   bundle's selected language file — that is governed by the running
    //   simulator's language and the app bundle's supported localisations.
    //   These tests therefore assert the locale-deterministic part (the
    //   formatted number and the presence of a unit word) and defer the
    //   English/German vocabulary assertion to end-to-end manual coverage
    //   (see spec Manual Checks).

    @Test("accessibilityDuration formats number under English locale and emits a unit word")
    func accessibilityDurationEnglishNumber() async {
        let formatted = ContinuousValueSlider<Double>.accessibilityDuration(1.2, locale: Self.enUS)
        #expect(formatted.hasPrefix("1.2 "))
        #expect(formatted.lowercased().contains("second") || formatted.lowercased().contains("sekund"))
    }

    @Test("accessibilityDuration formats number under German locale and emits a unit word")
    func accessibilityDurationGermanNumber() async {
        let formatted = ContinuousValueSlider<Double>.accessibilityDuration(1.2, locale: Self.deDE)
        #expect(formatted.hasPrefix("1,2 "))
        #expect(formatted.lowercased().contains("second") || formatted.lowercased().contains("sekund"))
    }

    @Test("accessibilityTempo formats integer and emits a unit phrase")
    func accessibilityTempoIntegerNumber() async {
        let formatted = ContinuousValueSlider<Double>.accessibilityTempo(120)
        #expect(formatted.hasPrefix("120 "))
        #expect(formatted.lowercased().contains("beat") || formatted.lowercased().contains("schl"))
    }

    // MARK: - Increment / Decrement Clamping

    @Test("increment adds step and clamps at upper bound")
    func incrementClampsAtUpperBound() async {
        #expect(ContinuousValueSlider<Double>.increment(1.0, by: 0.1, in: 0.3...3.0) == 1.1)
        #expect(ContinuousValueSlider<Double>.increment(2.95, by: 0.1, in: 0.3...3.0) == 3.0)
        #expect(ContinuousValueSlider<Double>.increment(3.0, by: 0.1, in: 0.3...3.0) == 3.0)
    }

    @Test("decrement subtracts step and clamps at lower bound")
    func decrementClampsAtLowerBound() async {
        #expect(ContinuousValueSlider<Double>.decrement(1.0, by: 0.1, in: 0.3...3.0) == 0.9)
        #expect(ContinuousValueSlider<Double>.decrement(0.35, by: 0.1, in: 0.3...3.0) == 0.3)
        #expect(ContinuousValueSlider<Double>.decrement(0.3, by: 0.1, in: 0.3...3.0) == 0.3)
    }

    @Test("increment and decrement work for integer-step ranges")
    func incrementWorksForIntegerStep() async {
        #expect(ContinuousValueSlider<Double>.increment(80, by: 1, in: 40...200) == 81)
        #expect(ContinuousValueSlider<Double>.increment(200, by: 1, in: 40...200) == 200)
        #expect(ContinuousValueSlider<Double>.decrement(40, by: 1, in: 40...200) == 40)
    }

    // MARK: - Enabled-State Predicates

    @Test("isIncrementEnabled is false at upper bound, true below")
    func incrementEnabledStateAtBounds() async {
        #expect(ContinuousValueSlider<Double>.isIncrementEnabled(at: 1.0, in: 0.3...3.0) == true)
        #expect(ContinuousValueSlider<Double>.isIncrementEnabled(at: 3.0, in: 0.3...3.0) == false)
    }

    @Test("isDecrementEnabled is false at lower bound, true above")
    func decrementEnabledStateAtBounds() async {
        #expect(ContinuousValueSlider<Double>.isDecrementEnabled(at: 1.0, in: 0.3...3.0) == true)
        #expect(ContinuousValueSlider<Double>.isDecrementEnabled(at: 0.3, in: 0.3...3.0) == false)
    }
}

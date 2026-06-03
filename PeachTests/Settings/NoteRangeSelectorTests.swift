import Testing
import SwiftUI
@testable import Peach

@Suite("NoteRangeSelector Tests")
struct NoteRangeSelectorTests {

    // MARK: - clampLower / clampUpper

    @Test("clampLower stops at upper minus minimumSpan")
    func clampLowerAtCeiling() async {
        let result = NoteRangeSelector.clampLower(MIDINote(80), against: MIDINote(84))
        #expect(result == MIDINote(72))
    }

    @Test("clampLower leaves candidate alone when well below the ceiling")
    func clampLowerBelowCeiling() async {
        let result = NoteRangeSelector.clampLower(MIDINote(50), against: MIDINote(84))
        #expect(result == MIDINote(50))
    }

    @Test("clampLower returns ceiling when candidate equals upper")
    func clampLowerAtUpper() async {
        let result = NoteRangeSelector.clampLower(MIDINote(84), against: MIDINote(84))
        #expect(result == MIDINote(72))
    }

    @Test("clampUpper stops at lower plus minimumSpan")
    func clampUpperAtFloor() async {
        let result = NoteRangeSelector.clampUpper(MIDINote(40), against: MIDINote(36))
        #expect(result == MIDINote(48))
    }

    @Test("clampUpper leaves candidate alone when well above the floor")
    func clampUpperAboveFloor() async {
        let result = NoteRangeSelector.clampUpper(MIDINote(96), against: MIDINote(36))
        #expect(result == MIDINote(96))
    }

    @Test("clampLower against an absurdly low upper bound returns a valid MIDINote (no precondition trap)")
    func clampLowerAgainstLowUpperStaysValid() async {
        let result = NoteRangeSelector.clampLower(MIDINote(60), against: MIDINote(5))
        #expect(MIDINote.validRange.contains(result.rawValue))
    }

    @Test("clampUpper against an absurdly high lower bound returns a valid MIDINote (no precondition trap)")
    func clampUpperAgainstHighLowerStaysValid() async {
        let result = NoteRangeSelector.clampUpper(MIDINote(60), against: MIDINote(120))
        #expect(MIDINote.validRange.contains(result.rawValue))
    }

    // MARK: - tapResolution

    @Test("Tap above the range moves the upper bound")
    func tapAboveMovesUpper() async {
        let outcome = NoteRangeSelector.tapResolution(at: MIDINote(91), lower: MIDINote(36), upper: MIDINote(84))
        #expect(outcome == .moveUpper(MIDINote(91)))
    }

    @Test("Tap below the range moves the lower bound")
    func tapBelowMovesLower() async {
        let outcome = NoteRangeSelector.tapResolution(at: MIDINote(33), lower: MIDINote(36), upper: MIDINote(84))
        #expect(outcome == .moveLower(MIDINote(33)))
    }

    @Test("Tap inside the range is a no-op")
    func tapInsideIsNoOp() async {
        let outcome = NoteRangeSelector.tapResolution(at: MIDINote(60), lower: MIDINote(36), upper: MIDINote(84))
        #expect(outcome == .noOp)
    }

    @Test("Tap on the lower bound itself is a no-op")
    func tapOnLowerBoundIsNoOp() async {
        let outcome = NoteRangeSelector.tapResolution(at: MIDINote(36), lower: MIDINote(36), upper: MIDINote(84))
        #expect(outcome == .noOp)
    }

    @Test("Tap on the upper bound itself is a no-op")
    func tapOnUpperBoundIsNoOp() async {
        let outcome = NoteRangeSelector.tapResolution(at: MIDINote(84), lower: MIDINote(36), upper: MIDINote(84))
        #expect(outcome == .noOp)
    }

    // MARK: - keyboardCommit

    @Test("Right arrow steps one semitone forward")
    func rightArrowSteps() async {
        let next = NoteRangeSelector.keyboardCommit(
            .rightArrow,
            modifiers: [],
            current: MIDINote(60),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == MIDINote(61))
    }

    @Test("Left arrow steps one semitone backward")
    func leftArrowSteps() async {
        let next = NoteRangeSelector.keyboardCommit(
            .leftArrow,
            modifiers: [],
            current: MIDINote(60),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == MIDINote(59))
    }

    @Test("Shift + right arrow steps one octave forward")
    func shiftRightArrowSteps() async {
        let next = NoteRangeSelector.keyboardCommit(
            .rightArrow,
            modifiers: .shift,
            current: MIDINote(60),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == MIDINote(72))
    }

    @Test("Shift + left arrow steps one octave backward")
    func shiftLeftArrowSteps() async {
        let next = NoteRangeSelector.keyboardCommit(
            .leftArrow,
            modifiers: .shift,
            current: MIDINote(60),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == MIDINote(48))
    }

    @Test("Home jumps to the legal range's lower bound")
    func homeJumpsToLowerBound() async {
        let next = NoteRangeSelector.keyboardCommit(
            .home,
            modifiers: [],
            current: MIDINote(60),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == MIDINote(21))
    }

    @Test("End jumps to the legal range's upper bound")
    func endJumpsToUpperBound() async {
        let next = NoteRangeSelector.keyboardCommit(
            .end,
            modifiers: [],
            current: MIDINote(60),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == MIDINote(108))
    }

    @Test("Right arrow at the upper edge clamps and returns nil")
    func rightArrowAtUpperEdgeReturnsNil() async {
        let next = NoteRangeSelector.keyboardCommit(
            .rightArrow,
            modifiers: [],
            current: MIDINote(108),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == nil)
    }

    @Test("Left arrow at the lower edge clamps and returns nil")
    func leftArrowAtLowerEdgeReturnsNil() async {
        let next = NoteRangeSelector.keyboardCommit(
            .leftArrow,
            modifiers: [],
            current: MIDINote(21),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == nil)
    }

    @Test("Shift + arrow clamps to the partner-imposed limit")
    func shiftArrowClampsAtPartnerLimit() async {
        // Lower marker focused at 60; upper bound forces partner-imposed ceiling at 72.
        let next = NoteRangeSelector.keyboardCommit(
            .rightArrow,
            modifiers: .shift,
            current: MIDINote(70),
            legalRange: MIDINote(21)...MIDINote(72)
        )
        #expect(next == MIDINote(72))
    }

    @Test("Home on a marker already at the legal floor returns nil")
    func homeAtFloorReturnsNil() async {
        let next = NoteRangeSelector.keyboardCommit(
            .home,
            modifiers: [],
            current: MIDINote(21),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == nil)
    }

    @Test("Unknown key returns nil")
    func unknownKeyReturnsNil() async {
        let next = NoteRangeSelector.keyboardCommit(
            .space,
            modifiers: [],
            current: MIDINote(60),
            legalRange: MIDINote(21)...MIDINote(108)
        )
        #expect(next == nil)
    }

    // MARK: - fitsWithoutScrolling

    @Test("Width below 416 pt requires scrolling")
    func widthJustBelowThresholdScrolls() async {
        #expect(!NoteRangeSelector.fitsWithoutScrolling(availableWidth: 415))
    }

    @Test("Width equal to 416 pt fits without scrolling")
    func widthAtThresholdFits() async {
        #expect(NoteRangeSelector.fitsWithoutScrolling(availableWidth: 416))
    }

    @Test("iPad-sized width fits without scrolling")
    func iPadWidthFits() async {
        #expect(NoteRangeSelector.fitsWithoutScrolling(availableWidth: 1024))
    }

    // MARK: - summaryLine

    @Test("Summary line contains both note names")
    func summaryLineContainsBothNames() async {
        let line = NoteRangeSelector.summaryLine(lower: MIDINote(36), upper: MIDINote(84))
        #expect(line.contains("C2"))
        #expect(line.contains("C6"))
    }
}

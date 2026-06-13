import SwiftUI

struct ChromaticConstructionScreen: View {
    @Environment(\.chromaticConstructionSession) private var session
    @Environment(\.userSettings) private var userSettings

    @State private var lowerAnchor: MIDINote = MIDINote(60)
    @State private var stepCount: Int = 7
    @State private var directionMode: ChromaticDirectionMode = .mix

    @State private var autoPlaybackTaskID: Int = 0
    @State private var resultMode: ResultMode = .fullSequence

    private enum ResultMode: Equatable {
        case fullSequence
        case tappedDot(index: Int)
    }

    var body: some View {
        VStack(spacing: 16) {
            controlsRow
            content
        }
        .padding()
        .navigationTitle(String(localized: "Walk the Steps"))
        .trainingScreen(helpSections: [], destination: .chromaticConstruction) {
            HStack(spacing: 6) {
                Image(systemName: "stairs")
                Text(String(localized: "Walk"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Walk the Steps"))
        }
        .onAppear { reconcileSession() }
        .onChange(of: lowerAnchor) { _, _ in restartTrial() }
        .onChange(of: stepCount) { _, _ in restartTrial() }
        .onChange(of: directionMode) { _, _ in restartTrial() }
        .onChange(of: ObjectIdentifier(session)) { _, _ in reconcileSession() }
        .task(id: autoPlaybackTaskID) {
            guard let completed = session.lastCompletedTrial,
                  session.state == .showingResult else { return }
            await runResultSequence(completed: completed)
        }
        .onChange(of: session.state == .showingResult) { _, isResult in
            if isResult {
                resultMode = .fullSequence
                autoPlaybackTaskID += 1
            }
        }
    }

    // MARK: - Subviews

    private var controlsRow: some View {
        VStack(spacing: 8) {
            HStack {
                ChromaticStepCountControl(stepCount: $stepCount)
                Spacer()
                ChromaticLowerAnchorSelector(anchor: $lowerAnchor)
                    .frame(maxWidth: 220)
            }
            ChromaticDirectionSelector(mode: $directionMode)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .showingResult:
            if let completed = session.lastCompletedTrial {
                ChromaticTrialResultView(
                    completed: completed,
                    onTapDot: { index in handleResultTap(index: index, in: completed) }
                )
            }
        case .walking, .idle:
            walkingContent
        }
    }

    @ViewBuilder
    private var walkingContent: some View {
        if let trial = session.currentTrial, let active = trial.active {
            ChromaticContourView(
                path: trial.path,
                placedOffsets: trial.placed.map(\.offset),
                audibleOffsets: trial.audibleOffsets,
                activePositionIndex: active.index,
                preservedValueForActive: active.preservedValue?.offset,
                isShowingResult: false,
                onRevertTo: { index in session.revertTo(positionIndex: index) },
                onDragStarted: { cents in
                    let freq = frequency(forCents: cents, lowerAnchor: trial.path.lowerAnchor)
                    session.startContinuousTone(at: freq)
                },
                onDragChanged: { cents in
                    let freq = frequency(forCents: cents, lowerAnchor: trial.path.lowerAnchor)
                    session.adjustContinuousTone(to: freq)
                },
                onCommit: { cents in
                    session.stopContinuousTone()
                    session.place(offset: cents)
                },
                onResultTap: { _ in }
            )
        } else {
            ProgressView()
        }
    }

    // MARK: - Lifecycle reconciliation

    private func reconcileSession() {
        let wantedAnchor = lowerAnchor
        let wantedInterval = interval(forStepCount: stepCount)
        let wantedSet = directionMode.outerIntervals(for: wantedInterval)
        if let trial = session.currentTrial,
           trial.path.lowerAnchor == wantedAnchor,
           wantedSet.contains(trial.path.outerInterval) {
            return
        }
        if !session.isIdle { session.stop() }
        startTrial()
    }

    private func restartTrial() {
        if !session.isIdle { session.stop() }
        startTrial()
    }

    private func startTrial() {
        let settings = ChromaticConstructionSettings.from(
            userSettings,
            lowerAnchor: lowerAnchor,
            outerIntervals: directionMode.outerIntervals(for: interval(forStepCount: stepCount))
        )
        session.start(settings: settings)
    }

    /// Maps a step-count picker value (2…12) to the corresponding `Interval`.
    /// The picker is constrained to `ChromaticStepCountControl.allowedStepCounts`,
    /// all of which correspond to valid `Interval.rawValue`s — the force-unwrap
    /// is the typed-throw-equivalent precondition for the constrained range.
    private func interval(forStepCount n: Int) -> Interval {
        guard let interval = Interval(rawValue: n) else {
            preconditionFailure("Step count \(n) out of Interval rawValue range; picker constrained to 2…12")
        }
        return interval
    }

    // MARK: - Result-mode autoplayback + auto-advance

    private func runResultSequence(completed: CompletedChromaticConstructionTrial) async {
        switch resultMode {
        case .fullSequence:
            await playFullSequence(completed: completed)
        case .tappedDot(let index):
            await playTappedDot(index: index, completed: completed)
        }
        guard session.state == .showingResult else { return }
        do { try await Task.sleep(for: .milliseconds(1500)) } catch { return }
        guard session.state == .showingResult else { return }
        session.stop()
        startTrial()
    }

    private func playFullSequence(completed: CompletedChromaticConstructionTrial) async {
        let lowerAnchorFreq = frequency(forCents: Cents(0), lowerAnchor: completed.trial.path.lowerAnchor)
        session.replay(frequency: lowerAnchorFreq)
        do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
        for entry in completed.trial.placed {
            guard session.state == .showingResult else { return }
            session.replay(frequency: frequency(forCents: entry.offset, lowerAnchor: completed.trial.path.lowerAnchor))
            do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
        }
    }

    private func playTappedDot(index: Int, completed: CompletedChromaticConstructionTrial) async {
        guard index >= 1, index <= completed.trial.placed.count else { return }
        let cents = completed.trial.placed[index - 1].offset
        session.replay(frequency: frequency(forCents: cents, lowerAnchor: completed.trial.path.lowerAnchor))
        do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
    }

    private func handleResultTap(index: Int, in completed: CompletedChromaticConstructionTrial) {
        guard index >= 1, index <= completed.trial.placed.count else { return }
        resultMode = .tappedDot(index: index)
        autoPlaybackTaskID += 1
    }

    // MARK: - Cent → Frequency

    private func frequency(forCents cents: Cents, lowerAnchor: MIDINote) -> Frequency {
        TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: lowerAnchor, offset: cents),
            referencePitch: userSettings.referencePitch
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ChromaticConstructionScreen()
    }
    .previewEnvironment()
}
#endif

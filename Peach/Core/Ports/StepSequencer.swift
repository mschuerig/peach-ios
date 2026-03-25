protocol StepSequencer {
    var currentStep: StepPosition? { get }
    var currentCycle: CycleDefinition? { get }
    var timing: SequencerTiming { get }
    func start(tempo: TempoBPM, stepProvider: any StepProvider) async throws
    func stop() async throws
    func playImmediateNote(velocity: MIDIVelocity) throws
}

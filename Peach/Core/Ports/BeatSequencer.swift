protocol BeatSequencer {
    var currentBeat: Beat? { get }
    var timing: SequencerTiming { get }
    func start(tempo: TempoBPM, beatProvider: any BeatProvider) async throws
    func stop() async throws
    func playImmediateNote(velocity: MIDIVelocity) throws
    func samplePosition(forHostTime hostTime: UInt64) -> Int64
}

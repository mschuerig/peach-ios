import SwiftUI

struct RhythmPOCScreen: View {
    @Environment(\.rhythmPlayer) private var rhythmPlayer
    @Environment(\.audioSampleRate) private var audioSampleRate

    @State private var tempo: TempoBPM = TempoBPM(120)
    @State private var playbackHandle: (any RhythmPlaybackHandle)?
    @State private var isPlaying = false

    private let tempoOptions: [TempoBPM] = [TempoBPM(80), TempoBPM(120), TempoBPM(160)]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            tempoPicker

            playButton

            Text(isPlaying ? "Playing..." : "Stopped")
                .font(.headline)
                .foregroundStyle(isPlaying ? .green : .secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Rhythm POC")
    }

    private var tempoPicker: some View {
        VStack(spacing: 8) {
            Text("\(tempo.value) BPM")
                .font(.largeTitle.monospacedDigit())

            Picker("Tempo", selection: $tempo) {
                ForEach(tempoOptions, id: \.self) { option in
                    Text("\(option.value)")
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
    }

    private var playButton: some View {
        Button {
            Task {
                await playPattern()
            }
        } label: {
            Label("Play Pattern", systemImage: "play.fill")
                .font(.title2)
                .frame(minWidth: 200, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }

    private func playPattern() async {
        // Stop previous if still playing
        try? await playbackHandle?.stop()
        playbackHandle = nil

        guard let rhythmPlayer else { return }

        let sixteenthDuration = tempo.sixteenthNoteDuration
        let samplesPerSixteenth = Int64(audioSampleRate.rawValue * sixteenthDuration.timeInterval)

        let clickNote = MIDINote(76)
        let velocity = MIDIVelocity(100)

        let events = (0..<4).map { i in
            RhythmPattern.Event(
                sampleOffset: Int64(i) * samplesPerSixteenth,
                midiNote: clickNote,
                velocity: velocity
            )
        }

        let pattern = RhythmPattern(
            events: events,
            sampleRate: audioSampleRate,
            totalDuration: sixteenthDuration * 4
        )

        do {
            let handle = try await rhythmPlayer.play(pattern)
            playbackHandle = handle
            isPlaying = true

            try? await Task.sleep(for: pattern.totalDuration)
            isPlaying = false
        } catch {
            isPlaying = false
        }
    }
}

import AsyncAlgorithms
import MIDIKitIO
import Observation
import os

@Observable
final class MIDIKitAdapter: MIDIInput {

    nonisolated var events: any AsyncSequence<MIDIInputEvent, Never> & Sendable { sharedEvents }

    private(set) var isConnected: Bool = false

    // MARK: - Private

    @ObservationIgnored
    private nonisolated(unsafe) var sharedEvents: any AsyncSequence<MIDIInputEvent, Never> & Sendable

    @ObservationIgnored
    private nonisolated(unsafe) var continuation: AsyncStream<MIDIInputEvent>.Continuation

    private let midiManager: ObservableMIDIManager

    private static let logger = Logger(subsystem: "com.peach.app", category: "MIDIKitAdapter")

    init() {
        var cont: AsyncStream<MIDIInputEvent>.Continuation!
        let stream = AsyncStream<MIDIInputEvent> { cont = $0 }
        self.continuation = cont
        self.sharedEvents = stream.share()

        midiManager = ObservableMIDIManager(
            clientName: "Peach",
            model: "Peach",
            manufacturer: "Peach"
        )

        do {
            try midiManager.start()
        } catch {
            Self.logger.warning("Failed to start MIDI manager: \(error)")
            return
        }

        let continuation = self.continuation
        do {
            try midiManager.addInputConnection(
                to: .allOutputs,
                tag: "main",
                filter: .default(),
                receiver: .events(options: [.filterActiveSensingAndClock]) { events, timeStamp, _ in
                    for event in events {
                        let mapped: MIDIInputEvent? = switch event {
                        case .noteOn(let payload):
                            payload.velocity.midi1Value == 0
                                ? .noteOff(
                                    note: MIDINote(Int(payload.note.number)),
                                    velocity: MIDIVelocity(max(1, UInt8(payload.velocity.midi1Value))),
                                    timestamp: timeStamp
                                )
                                : .noteOn(
                                    note: MIDINote(Int(payload.note.number)),
                                    velocity: MIDIVelocity(UInt8(payload.velocity.midi1Value)),
                                    timestamp: timeStamp
                                )
                        case .noteOff(let payload):
                            .noteOff(
                                note: MIDINote(Int(payload.note.number)),
                                velocity: MIDIVelocity(max(1, UInt8(payload.velocity.midi1Value))),
                                timestamp: timeStamp
                            )
                        case .pitchBend(let payload):
                            .pitchBend(
                                value: PitchBendValue(UInt16(payload.value.midi1Value)),
                                channel: MIDIChannel(UInt8(payload.channel)),
                                timestamp: timeStamp
                            )
                        default:
                            nil
                        }
                        if let mapped {
                            continuation.yield(mapped)
                        }
                    }
                }
            )
        } catch {
            Self.logger.warning("Failed to add MIDI input connection: \(error)")
        }

        midiManager.notificationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateConnectionStatus()
            }
        }
        updateConnectionStatus()
    }

    deinit {
        continuation.finish()
    }

    private func updateConnectionStatus() {
        isConnected = !(midiManager.managedInputConnections["main"]?.coreMIDIOutputEndpointRefs.isEmpty ?? true)
    }
}

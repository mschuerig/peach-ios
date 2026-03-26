import MIDIKitIO
import Observation
import os

@Observable
final class MIDIKitAdapter: MIDIInput {

    nonisolated var events: AsyncStream<MIDIInputEvent> { _events }

    private(set) var isConnected: Bool = false

    // MARK: - Private

    @ObservationIgnored
    private nonisolated(unsafe) var _events: AsyncStream<MIDIInputEvent>

    @ObservationIgnored
    private nonisolated(unsafe) var continuation: AsyncStream<MIDIInputEvent>.Continuation

    private let midiManager: ObservableMIDIManager

    private static let logger = Logger(subsystem: "com.peach.app", category: "MIDIKitAdapter")

    init() {
        var continuation: AsyncStream<MIDIInputEvent>.Continuation!
        _events = AsyncStream { continuation = $0 }
        self.continuation = continuation

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

        let cont = continuation!
        do {
            try midiManager.addInputConnection(
                to: .allOutputs,
                tag: "main",
                filter: .default(),
                receiver: .events(options: [.filterActiveSensingAndClock]) { events, timeStamp, _ in
                    for event in events {
                        switch event {
                        case .noteOn(let payload):
                            let velocity = payload.velocity.midi1Value
                            let note = MIDINote(Int(payload.note.number))
                            if velocity == 0 {
                                cont.yield(.noteOff(
                                    note: note,
                                    velocity: MIDIVelocity(max(1, UInt8(velocity))),
                                    timestamp: timeStamp
                                ))
                            } else {
                                cont.yield(.noteOn(
                                    note: note,
                                    velocity: MIDIVelocity(UInt8(velocity)),
                                    timestamp: timeStamp
                                ))
                            }
                        case .noteOff(let payload):
                            cont.yield(.noteOff(
                                note: MIDINote(Int(payload.note.number)),
                                velocity: MIDIVelocity(max(1, UInt8(payload.velocity.midi1Value))),
                                timestamp: timeStamp
                            ))
                        case .pitchBend(let payload):
                            cont.yield(.pitchBend(
                                value: PitchBendValue(UInt16(payload.value.midi1Value)),
                                channel: MIDIChannel(UInt8(payload.channel)),
                                timestamp: timeStamp
                            ))
                        default:
                            break
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

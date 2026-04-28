/// Port protocol for persisting training-record envelopes.
///
/// Discipline-specific adapters encode their payloads into ``TrainingRecord``
/// envelopes and delegate persistence to this protocol, keeping the data store
/// free of discipline knowledge.
protocol TrainingRecordPersisting {
    func save(_ envelope: TrainingRecord) throws
}

/// Top-level alias — points at the current schema version's nested type.
/// Update this when adding a new schema version.
/// Maps the renamed public type to the unchanged SwiftData entity name,
/// avoiding a schema migration for a purely cosmetic rename.
typealias TimingOffsetDetectionRecord = SchemaV1.RhythmOffsetDetectionRecord

extension TimingOffsetDetectionRecord: Timestamped {}

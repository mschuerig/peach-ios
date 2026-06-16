import Foundation
import SwiftData

/// Decides whether a `ModelContainer` initialization failure means the on-disk
/// store is schema-incompatible with `SchemaV1` — the single condition under
/// which wiping `default.store{,-shm,-wal}` is the correct recovery.
///
/// Lives next to `PeachSchema` so a future schema bump can update the
/// classifier in the same edit that introduces a new `VersionedSchema`. The
/// classifier intentionally matches a narrow set; everything else propagates
/// from the caller's catch so user data is never destroyed by a transient
/// disk-full, file-permission, encrypted-store, or corrupted-shm/wal error.
///
/// The schema-incompatibility set:
///
/// - `SwiftDataError.loadIssueModelContainer`
/// - `SwiftDataError.backwardMigration`
/// - `SwiftDataError.unknownSchema`
/// - `NSCocoaErrorDomain` / `NSPersistentStoreIncompatibleVersionHashError`
///   (code 134100), the underlying Core Data error code SwiftData may pass
///   through unwrapped. `CocoaError(.persistentStoreIncompatibleVersionHash)`
///   bridges to the same NSError shape, so a single check covers both forms.
///
/// The three `SwiftDataError` cases are the members of the "Container" and
/// "Migration" groupings on
/// <https://developer.apple.com/documentation/swiftdata/swiftdataerror>;
/// Apple does not publish prose stating "schema mismatch ⇒ these cases", so
/// this is calibrated narrow matching, not a guarantee.
enum PeachSchemaCompatibility {

    /// Returns `true` when `error` matches a known schema-incompatibility
    /// signal. All other failures return `false` so the caller rethrows.
    static func shouldWipeStore(after error: Error) -> Bool {
        switch error {
        case SwiftDataError.loadIssueModelContainer,
             SwiftDataError.backwardMigration,
             SwiftDataError.unknownSchema:
            return true
        default:
            let nserror = error as NSError
            return nserror.domain == NSCocoaErrorDomain
                && nserror.code == CocoaError.Code.persistentStoreIncompatibleVersionHash.rawValue
        }
    }
}

import Testing
import Foundation
import SwiftData
@testable import Peach

@Suite("setupDataStore error classifier")
struct PeachAppDataStoreClassifierTests {

    // MARK: - Schema-incompatibility cases (wipe is the documented recovery)

    @Test("SwiftDataError.loadIssueModelContainer triggers wipe")
    func loadIssueModelContainerWipes() async {
        #expect(PeachApp.shouldWipeStore(after: SwiftDataError.loadIssueModelContainer))
    }

    @Test("SwiftDataError.backwardMigration triggers wipe")
    func backwardMigrationWipes() async {
        #expect(PeachApp.shouldWipeStore(after: SwiftDataError.backwardMigration))
    }

    @Test("SwiftDataError.unknownSchema triggers wipe")
    func unknownSchemaWipes() async {
        #expect(PeachApp.shouldWipeStore(after: SwiftDataError.unknownSchema))
    }

    @Test("CocoaError persistentStoreIncompatibleVersionHash triggers wipe")
    func persistentStoreIncompatibleVersionHashWipes() async {
        #expect(PeachApp.shouldWipeStore(after: CocoaError(.persistentStoreIncompatibleVersionHash)))
    }

    @Test("Raw NSError with NSCocoaErrorDomain hash-mismatch code triggers wipe")
    func bridgedNSErrorHashMismatchWipes() async {
        // 134140 = NSPersistentStoreIncompatibleVersionHashError. Verifies the
        // NSError-fallback path in `shouldWipeStore`: `as? CocoaError` does NOT
        // bridge a bare-constructed NSError, so the explicit domain+code check
        // is what matches here.
        let bridged: Error = NSError(domain: NSCocoaErrorDomain, code: 134140)
        #expect(PeachApp.shouldWipeStore(after: bridged))
    }


    // MARK: - Non-schema cases (must not wipe — would destroy user data)

    @Test("CocoaError fileWriteOutOfSpace does not wipe (disk full)")
    func diskFullDoesNotWipe() async {
        #expect(PeachApp.shouldWipeStore(after: CocoaError(.fileWriteOutOfSpace)) == false)
    }

    @Test("CocoaError fileWriteNoPermission does not wipe")
    func writePermissionDeniedDoesNotWipe() async {
        #expect(PeachApp.shouldWipeStore(after: CocoaError(.fileWriteNoPermission)) == false)
    }

    @Test("CocoaError fileReadNoPermission does not wipe (encrypted store / device locked)")
    func readPermissionDeniedDoesNotWipe() async {
        #expect(PeachApp.shouldWipeStore(after: CocoaError(.fileReadNoPermission)) == false)
    }

    @Test("CocoaError persistentStoreOpen does not wipe (matrix row 6: corrupt shm/wal)")
    func persistentStoreOpenDoesNotWipe() async {
        #expect(PeachApp.shouldWipeStore(after: CocoaError(.persistentStoreOpen)) == false)
    }

    @Test("CocoaError fileReadCorruptFile does not wipe (matrix row 6: sqlite corruption)")
    func sqliteCorruptionDoesNotWipe() async {
        #expect(PeachApp.shouldWipeStore(after: CocoaError(.fileReadCorruptFile)) == false)
    }

    @Test("SwiftDataError outside the wipe set does not wipe")
    func unrelatedSwiftDataErrorDoesNotWipe() async {
        #expect(PeachApp.shouldWipeStore(after: SwiftDataError.unsupportedPredicate) == false)
    }

    @Test("Arbitrary NSError does not wipe")
    func arbitraryErrorDoesNotWipe() async {
        let arbitrary = NSError(domain: "test.peach", code: 12345)
        #expect(PeachApp.shouldWipeStore(after: arbitrary) == false)
    }
}

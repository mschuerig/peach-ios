protocol CSVFormatMigration {
    var sourceVersion: Int { get }
    var targetVersion: Int { get }
    func migrate(rows: [[String: String]]) -> [[String: String]]
}

enum CSVMigrationChain {

    private static let migrations: [any CSVFormatMigration] = [
        V1ToV2Migration(),
        V2ToV3Migration(),
    ]

    static func migrate(from sourceVersion: Int, to targetVersion: Int, rows: [[String: String]]) -> [[String: String]]? {
        var currentRows = rows
        var currentVersion = sourceVersion

        while currentVersion < targetVersion {
            guard let migration = migrations.first(where: { $0.sourceVersion == currentVersion }) else {
                return nil
            }
            currentRows = migration.migrate(rows: currentRows)
            currentVersion = migration.targetVersion
        }

        return currentRows
    }
}

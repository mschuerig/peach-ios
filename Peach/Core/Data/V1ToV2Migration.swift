struct V1ToV2Migration: CSVFormatMigration {

    let sourceVersion = 1
    let targetVersion = 2

    func migrate(rows: [[String: String]]) -> [[String: String]] {
        rows.map { row in
            var migrated = row

            // Rename pitchComparison → pitchDiscrimination
            if migrated["trainingType"] == "pitchComparison" {
                migrated["trainingType"] = "pitchDiscrimination"
            }

            // Add V2 rhythm columns with empty defaults
            migrated["tempoBPM"] = migrated["tempoBPM"] ?? ""
            migrated["offsetMs"] = migrated["offsetMs"] ?? ""
            migrated["userOffsetMs"] = migrated["userOffsetMs"] ?? ""

            return migrated
        }
    }
}

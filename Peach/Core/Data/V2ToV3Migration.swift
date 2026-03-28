struct V2ToV3Migration: CSVFormatMigration {

    let sourceVersion = 2
    let targetVersion = 3

    func migrate(rows: [[String: String]]) -> [[String: String]] {
        rows.map { row in
            var migrated = row

            // Rename rhythmMatching → continuousRhythmMatching
            if migrated["trainingType"] == "rhythmMatching" {
                migrated["trainingType"] = "continuousRhythmMatching"
            }

            // Map userOffsetMs → meanOffsetMs (best available approximation)
            let userOffset = migrated.removeValue(forKey: "userOffsetMs") ?? ""
            migrated["meanOffsetMs"] = migrated["meanOffsetMs"] ?? userOffset
            migrated["meanOffsetMsPosition0"] = migrated["meanOffsetMsPosition0"] ?? ""
            migrated["meanOffsetMsPosition1"] = migrated["meanOffsetMsPosition1"] ?? ""
            migrated["meanOffsetMsPosition2"] = migrated["meanOffsetMsPosition2"] ?? ""
            migrated["meanOffsetMsPosition3"] = migrated["meanOffsetMsPosition3"] ?? ""

            return migrated
        }
    }
}

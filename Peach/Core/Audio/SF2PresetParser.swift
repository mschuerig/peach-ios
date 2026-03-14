import Foundation

struct SF2Preset: SoundSourceID, Equatable, Hashable {
    let name: String
    let program: Int
    let bank: Int

    var rawValue: String { "sf2:\(bank):\(program)" }
    var displayName: String { name }
}

enum SF2ParseError: Error {
    case fileNotReadable
    case invalidRIFFHeader
    case missingPDTAChunk
    case missingPHDRChunk
    case invalidPHDRData
}

enum SF2PresetParser {

    private static let phdrRecordSize = 38
    private static let riffHeaderID: [UInt8] = [0x52, 0x49, 0x46, 0x46] // "RIFF"
    private static let sfbkID: [UInt8] = [0x73, 0x66, 0x62, 0x6B]       // "sfbk"
    private static let listID: [UInt8] = [0x4C, 0x49, 0x53, 0x54]       // "LIST"
    private static let pdtaID: [UInt8] = [0x70, 0x64, 0x74, 0x61]       // "pdta"
    private static let phdrID: [UInt8] = [0x70, 0x68, 0x64, 0x72]       // "phdr"

    static func parsePresets(from url: URL) throws -> [SF2Preset] {
        guard let data = try? Data(contentsOf: url) else {
            throw SF2ParseError.fileNotReadable
        }

        guard data.count >= 12 else {
            throw SF2ParseError.invalidRIFFHeader
        }

        // Verify RIFF header
        guard matches(data: data, offset: 0, expected: riffHeaderID) else {
            throw SF2ParseError.invalidRIFFHeader
        }

        // Verify sfbk form type at offset 8
        guard matches(data: data, offset: 8, expected: sfbkID) else {
            throw SF2ParseError.invalidRIFFHeader
        }

        // Find pdta LIST chunk
        let pdtaRange = try findPDTAChunk(in: data)

        // Find phdr sub-chunk within pdta
        let phdrData = try findPHDRSubChunk(in: data, pdtaRange: pdtaRange)

        // Parse 38-byte PHDR records, excluding the last (EOP sentinel)
        return parsePHDRRecords(from: phdrData)
    }

    // MARK: - RIFF Navigation

    private static func findPDTAChunk(in data: Data) throws -> Range<Int> {
        var offset = 12 // skip RIFF header (4) + size (4) + sfbk (4)

        while offset + 8 <= data.count {
            let chunkID = Array(data[offset..<offset + 4])
            let chunkSize = readUInt32LE(data: data, offset: offset + 4)

            if chunkID == listID {
                // LIST chunk — check form type
                let formType = Array(data[offset + 8..<offset + 12])
                if formType == pdtaID {
                    let contentStart = offset + 12
                    let contentEnd = offset + 8 + Int(chunkSize)
                    return contentStart..<contentEnd
                }
            }

            // Advance to next chunk (8 bytes header + chunk size, padded to even)
            let totalChunkSize = 8 + Int(chunkSize)
            offset += totalChunkSize + (totalChunkSize % 2) // RIFF chunks are word-aligned
        }

        throw SF2ParseError.missingPDTAChunk
    }

    private static func findPHDRSubChunk(in data: Data, pdtaRange: Range<Int>) throws -> Data {
        var offset = pdtaRange.lowerBound

        while offset + 8 <= pdtaRange.upperBound {
            let chunkID = Array(data[offset..<offset + 4])
            let chunkSize = readUInt32LE(data: data, offset: offset + 4)

            if chunkID == phdrID {
                let contentStart = offset + 8
                let contentEnd = contentStart + Int(chunkSize)
                guard contentEnd <= data.count else {
                    throw SF2ParseError.invalidPHDRData
                }
                return data[contentStart..<contentEnd]
            }

            let totalSubChunkSize = 8 + Int(chunkSize)
            offset += totalSubChunkSize + (totalSubChunkSize % 2)
        }

        throw SF2ParseError.missingPHDRChunk
    }

    // MARK: - PHDR Record Parsing

    private static func parsePHDRRecords(from phdrData: Data) -> [SF2Preset] {
        let recordCount = phdrData.count / phdrRecordSize
        guard recordCount > 1 else { return [] }

        // Drop the last record (EOP sentinel)
        let presetCount = recordCount - 1
        var presets: [SF2Preset] = []
        presets.reserveCapacity(presetCount)

        let baseOffset = phdrData.startIndex

        for i in 0..<presetCount {
            let recordStart = baseOffset + i * phdrRecordSize

            // achPresetName: 20 bytes ASCII, null-padded
            let nameData = phdrData[recordStart..<recordStart + 20]
            let name = cleanPresetName(nameData)

            // wPreset: UInt16 LE at offset 20
            let program = Int(readUInt16LE(data: phdrData, offset: recordStart + 20))

            // wBank: UInt16 LE at offset 22
            let bank = Int(readUInt16LE(data: phdrData, offset: recordStart + 22))

            presets.append(SF2Preset(name: name, program: program, bank: bank))
        }

        return presets
    }

    private static func cleanPresetName(_ data: Data) -> String {
        // Replace null bytes, then trim whitespace
        let bytes = Array(data)
        // Find first null byte to truncate
        let endIndex = bytes.firstIndex(of: 0) ?? bytes.count
        let nameBytes = Array(bytes[0..<endIndex])

        let name = String(bytes: nameBytes, encoding: .ascii)
            ?? String(bytes: nameBytes, encoding: .utf8)
            ?? ""

        return name.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Binary Helpers

    private static func readUInt32LE(data: Data, offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    private static func readUInt16LE(data: Data, offset: Int) -> UInt16 {
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1]) << 8
        return b0 | b1
    }

    private static func matches(data: Data, offset: Int, expected: [UInt8]) -> Bool {
        guard offset + expected.count <= data.count else { return false }
        for i in 0..<expected.count {
            if data[offset + i] != expected[i] { return false }
        }
        return true
    }
}

import SwiftUI
import os

@MainActor
enum ChartImageRenderer {

    private static let logger = Logger(subsystem: "Peach", category: "ChartImageRenderer")

    private static var lastRenderedURLs: [TrainingDisciplineID: URL] = [:]

    static func render(mode: TrainingDisciplineID, progressTimeline: ProgressTimeline, date: Date = Date()) -> URL? {
        let view = ExportChartView(mode: mode, progressTimeline: progressTimeline, date: date)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }
        #if os(iOS)
        let image = UIImage(cgImage: cgImage)
        guard let pngData = image.pngData() else { return nil }
        #else
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        #endif
        let fileName = exportFileName(for: date, mode: mode)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: url)
            if let previous = lastRenderedURLs[mode], previous != url {
                try? FileManager.default.removeItem(at: previous)
            }
            lastRenderedURLs[mode] = url
            return url
        } catch {
            logger.warning("Failed to write chart image: \(error.localizedDescription)")
            return nil
        }
    }

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    static func exportFileName(for date: Date = Date(), mode: TrainingDisciplineID) -> String {
        let timestamp = fileNameFormatter.string(from: date)
        return "peach-\(mode.slug)-\(timestamp).png"
    }
}

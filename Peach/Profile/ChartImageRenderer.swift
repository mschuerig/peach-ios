import SwiftUI
import os

enum ChartImageRenderer {

    private static let logger = Logger(subsystem: "Peach", category: "ChartImageRenderer")

    private static var lastRenderedURLs: [TrainingDisciplineID: URL] = [:]

    static func render(mode: TrainingDisciplineID, progressTimeline: ProgressTimeline, date: Date = Date()) -> URL? {
        let view = ExportChartView(mode: mode, progressTimeline: progressTimeline, date: date)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else { return nil }
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

    static func exportFileName(for date: Date = Date(), mode: TrainingDisciplineID) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let timestamp = formatter.string(from: date)
        return "peach-\(mode.slug)-\(timestamp).png"
    }
}

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
        guard let cgImage = renderer.cgImage,
              let pngData = pngData(from: cgImage, scale: renderer.scale) else { return nil }
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

    static func pngData(from cgImage: CGImage, scale: CGFloat) -> Data? {
        #if os(iOS)
        UIImage(cgImage: cgImage).pngData()
        #else
        let size = NSSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        let image = NSImage(cgImage: cgImage, size: size)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }

    static func exportFileName(for date: Date = Date(), mode: TrainingDisciplineID) -> String {
        let timestamp = fileNameFormatter.string(from: date)
        return "peach-\(mode.slug)-\(timestamp).png"
    }
}

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import CoreGraphics

/// Centralizes platform-specific image encoding.
enum PlatformImage {
    /// Encodes a `CGImage` as PNG data.
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
}

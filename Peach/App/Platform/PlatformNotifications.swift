#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#else
#error("Unsupported platform")
#endif

/// Centralizes platform-specific notification names for background/foreground transitions.
enum PlatformNotifications {
    #if os(iOS)
    static let background: Notification.Name = UIApplication.didEnterBackgroundNotification
    static let foreground: Notification.Name = UIApplication.willEnterForegroundNotification
    #elseif os(macOS)
    static let background: Notification.Name = NSApplication.didResignActiveNotification
    static let foreground: Notification.Name = NSApplication.didBecomeActiveNotification
    #else
    #error("Unsupported platform")
    #endif
}

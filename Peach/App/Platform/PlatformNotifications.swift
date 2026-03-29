#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Centralizes platform-specific notification names for background/foreground transitions.
enum PlatformNotifications {
    #if os(iOS)
    static let background: Notification.Name = UIApplication.didEnterBackgroundNotification
    static let foreground: Notification.Name = UIApplication.willEnterForegroundNotification
    #else
    static let background: Notification.Name = NSApplication.didResignActiveNotification
    static let foreground: Notification.Name = NSApplication.didBecomeActiveNotification
    #endif
}

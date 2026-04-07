#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class HelpPanelController: NSObject, NSWindowDelegate {
    static let shared = HelpPanelController()

    private var window: NSWindow?
    private var onDismiss: (() -> Void)?

    func show(
        title: String,
        sections: [HelpSection],
        onDismiss: (() -> Void)? = nil
    ) {
        self.onDismiss = onDismiss

        if let window {
            window.contentView = NSHostingView(rootView: helpView(for: sections))
            window.title = title
            window.orderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: helpView(for: sections))
        window.contentMinSize = NSSize(width: 350, height: 250)
        window.center()
        window.orderFront(nil)
        self.window = window
    }

    func show(content: HelpSheetContent) {
        show(title: content.title, sections: content.sections)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            onDismiss?()
            onDismiss = nil
        }
    }

    private func helpView(for sections: [HelpSection]) -> some View {
        ScrollView {
            HelpContentView(sections: sections)
                .padding()
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}
#endif

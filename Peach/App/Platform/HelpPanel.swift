#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class HelpPanelController: NSObject, NSWindowDelegate {
    static let shared = HelpPanelController()

    private var window: NSWindow?
    private var onDismiss: (() -> Void)?

    /// True while the open window shows training help opened *from a training
    /// screen* — that help is about the current discipline, so it follows the
    /// discipline when the user switches (see `updateIfShowingTrainingHelp`).
    /// Help opened explicitly from the Help menu, or "About Peach", is pinned.
    private var isTrainingHelp = false

    func show(
        title: String,
        sections: [HelpSection],
        onDismiss: (() -> Void)? = nil,
        followsTrainingDiscipline: Bool = false
    ) {
        // Only adopt a new dismiss owner when one is provided. Menu-Help and
        // "About Peach" pass none; if they retarget a window opened from a
        // training screen (which paused the session), preserving that screen's
        // `onDismiss` ensures the pause is still released when the window closes,
        // rather than being orphaned — which would leave the session suspended.
        if let onDismiss { self.onDismiss = onDismiss }
        self.isTrainingHelp = followsTrainingDiscipline
        let content = HelpContentView(sections: sections)
        showView(title: title, content: content)
    }

    /// Re-points an open, discipline-following training-help window at a new
    /// discipline's help. Called when the foreground discipline changes. Swaps
    /// content in place without re-ordering, so the training window keeps focus.
    /// No-op when no window is open or the open window is pinned (menu / About).
    func updateIfShowingTrainingHelp(title: String, sections: [HelpSection]) {
        guard let window, isTrainingHelp else { return }
        window.contentView = makeHostingView(HelpContentView(sections: sections))
        window.title = title
    }

    func show<V: View>(title: String, view: V, onDismiss: (() -> Void)? = nil) {
        // "About Peach" pins (does not follow a discipline). Adopt a new dismiss
        // owner only when provided; otherwise preserve any pending training-screen
        // `onDismiss` so a suspended session is still released on window close.
        if let onDismiss { self.onDismiss = onDismiss }
        self.isTrainingHelp = false
        showView(title: title, content: view)
    }

    func show(content: HelpSheetContent) {
        show(title: content.title, sections: content.sections)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            onDismiss?()
            onDismiss = nil
            // Reset provenance so a later pinned (menu / About) window is never
            // mistaken for a discipline-following one by updateIfShowingTrainingHelp.
            isTrainingHelp = false
        }
    }

    private func makeHostingView<V: View>(_ content: V) -> NSView {
        let hosted = ScrollView {
            content
                .padding()
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 350, minHeight: 250)
        return NSHostingView(rootView: hosted)
    }

    private func showView<V: View>(title: String, content: V) {
        if let window {
            window.contentView = makeHostingView(content)
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
        window.contentView = makeHostingView(content)
        window.contentMinSize = NSSize(width: 350, height: 250)
        window.center()
        window.orderFront(nil)
        self.window = window
    }
}
#endif

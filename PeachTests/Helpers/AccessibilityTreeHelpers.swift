#if canImport(UIKit)
import Foundation
import SwiftUI
import UIKit

/// Returns the vertical space SwiftUI requires to render `view` at
/// `proposedWidth`. The caller must apply any `.frame(width:)` and
/// `.environment(\.dynamicTypeSize, …)` modifiers on the view itself —
/// `sizeThatFits(in:)`'s width is a layout *proposal*, not a constraint on
/// the inner `Text`. Used by the Story 85.6 AX1 wrap test to detect whether
/// a header wraps to multiple lines.
@MainActor
enum AccessibilityTreeHelpers {

    static func renderedHeight(
        of view: some View,
        proposedWidth: CGFloat
    ) -> CGFloat {
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: proposedWidth, height: CGFloat.greatestFiniteMagnitude)).height
    }
}
#endif

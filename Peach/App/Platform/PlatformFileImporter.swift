import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Platform-unified file importer using SwiftUI's `.fileImporter()` on all platforms.
    /// Cancellation is filtered out; `onResult` is only called on success or a real error.
    func platformFileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        onResult: @escaping (Result<URL, any Error>) -> Void
    ) -> some View {
        self.fileImporter(
            isPresented: isPresented,
            allowedContentTypes: allowedContentTypes
        ) { result in
            if case .failure(let error) = result,
               (error as? CocoaError)?.code == .userCancelled {
                return
            }
            onResult(result)
        }
    }
}

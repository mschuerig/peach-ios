import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Platform-unified file importer. Cancellation is filtered out on both platforms;
    /// `onResult` is only called on success or a real error.
    func platformFileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        onResult: @escaping (Result<URL, any Error>) -> Void
    ) -> some View {
        #if os(iOS)
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
        #elseif os(macOS)
        self.onChange(of: isPresented.wrappedValue) {
            guard isPresented.wrappedValue else { return }
            defer { isPresented.wrappedValue = false }
            let panel = NSOpenPanel()
            panel.allowedContentTypes = allowedContentTypes
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            onResult(.success(url))
        }
        #else
        #error("Unsupported platform")
        #endif
    }
}

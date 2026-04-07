import SwiftUI
import UniformTypeIdentifiers

extension View {
    func platformFileImporter(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        onResult: @escaping (Result<URL, any Error>) -> Void
    ) -> some View {
        #if os(iOS)
        self.fileImporter(
            isPresented: isPresented,
            allowedContentTypes: allowedContentTypes,
            onCompletion: onResult
        )
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

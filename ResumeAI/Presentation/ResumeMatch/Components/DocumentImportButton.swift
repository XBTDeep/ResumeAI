import SwiftUI
import UniformTypeIdentifiers

struct DocumentImportButton: View {
    let onPick: (URL) -> Void
    @State private var isImporterPresented = false

    var body: some View {
        Button {
            isImporterPresented = true
        } label: {
            Label("Document", systemImage: "doc.text.fill")
        }
        .buttonStyle(.bordered)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf, .plainText, .rtf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                onPick(url)
            }
        }
    }
}

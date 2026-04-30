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
        .buttonStyle(.plain)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.resumeBlue)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.resumeBlue.opacity(0.08), in: Capsule())
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

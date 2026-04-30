import PhotosUI
import SwiftUI

struct ImageImportButton: View {
    let onPick: (URL) -> Void
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label("Image", systemImage: "photo.fill.on.rectangle.fill")
        }
        .buttonStyle(.bordered)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("resume-image-\(UUID().uuidString).jpg")
                    try? data.write(to: url)
                    await MainActor.run { onPick(url) }
                }
            }
        }
    }
}

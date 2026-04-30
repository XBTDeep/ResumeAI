import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ResumeMatchView: View {
    @StateObject var viewModel: ResumeMatchViewModel
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 22) {
                    header
                    inputCard
                    if viewModel.isAnalyzing {
                        loadingCard
                    }
                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    }
                    if let analysis = viewModel.analysis {
                        AnalysisResultCard(analysis: analysis)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !viewModel.isAnalyzing {
                        emptyStateCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 880)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.93, green: 0.96, blue: 0.99), .white, Color(red: 0.94, green: 0.98, blue: 0.97)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.resumeBlue.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 24)
                .offset(x: 90, y: -120)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [.resumeBlue, .resumeTeal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "briefcase.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 3) {
                    Text("ResumeAI")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.resumeInk)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Label("PDF + Image OCR", systemImage: "text.viewfinder")
                Label("Job links", systemImage: "link")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.resumeBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare your resume to a job")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.resumeInk)
                    Text("Upload a resume, add a job link, and get a practical scorecard.")
                        .font(.subheadline)
                        .foregroundStyle(Color.resumeMuted)
                }
                Spacer()
            }

            Divider()
                .overlay(Color.resumeBorder)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                Text("Resume")
                    .font(.headline)
                    .foregroundStyle(Color.resumeInk)

                ResumeUploadButton(
                    onDocumentPick: { viewModel.attachDocument(url: $0) },
                    onImagePick: { viewModel.attachImage(url: $0) }
                )
                if !viewModel.selectedResumeName.isEmpty {
                    HStack(spacing: 10) {
                        Label(viewModel.selectedResumeName, systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.resumeTeal)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Button("Clear") { viewModel.clearResumeAttachment() }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                }
            }

            Divider()
                .overlay(Color.resumeBorder)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 12) {
                Text("Job")
                    .font(.headline)
                    .foregroundStyle(Color.resumeInk)

                Picker("Job input", selection: $viewModel.inputMode) {
                    ForEach(JobInputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)

                if viewModel.inputMode == .url {
                    HStack(spacing: 10) {
                        Button {
                            if let pasteboardText = UIPasteboard.general.string {
                                viewModel.jobURLText = pasteboardText
                            }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                                .font(.caption.weight(.bold))
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.resumeBlue)

                        TextField(
                            "",
                            text: $viewModel.jobURLText,
                            prompt: Text("position link here")
                                .foregroundColor(Color.resumeMuted.opacity(0.45))
                        )
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .jobURL)
                        .foregroundStyle(Color.resumeInk)
                        .tint(Color.resumeBlue)

                        if !viewModel.jobURLText.isEmpty {
                            Button {
                                viewModel.jobURLText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.resumeMuted.opacity(0.65))
                            .accessibilityLabel("Clear job link")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.resumeSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.resumeBorder, lineWidth: 1)
                    )
                } else {
                    TextEditor(text: $viewModel.jobText)
                        .focused($focusedField, equals: .jobText)
                        .frame(minHeight: 124)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.resumeSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            Button {
                focusedField = nil
                Task { await viewModel.analyze() }
            } label: {
                HStack {
                    if viewModel.isAnalyzing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(viewModel.isAnalyzing ? "Analyzing" : "Analyze Match")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .background(viewModel.canAnalyze ? Color.resumeBlue : Color.resumeMuted.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
            .disabled(!viewModel.canAnalyze)
        }
        .padding(20)
        .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.resumeBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 24, x: 0, y: 16)
    }

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.resumeBlue)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.loadingMessage.isEmpty ? "Analyzing..." : viewModel.loadingMessage)
                    .font(.headline)
                    .foregroundStyle(Color.resumeInk)
                Text("Fast local scoring first, then tailored suggestions.")
                    .font(.subheadline)
                    .foregroundStyle(Color.resumeMuted)
            }
            Spacer()
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.resumeBorder, lineWidth: 1))
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.badge.waveform.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.resumeBlue)
            Text("Your scorecard will appear here")
                .font(.headline)
                .foregroundStyle(Color.resumeInk)
            Text("We’ll show strengths, gaps, matched keywords, and rewrite ideas in a recruiter-friendly format.")
                .font(.subheadline)
                .foregroundStyle(Color.resumeMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.resumeBorder, lineWidth: 1))
    }

    private enum Field {
        case jobURL
        case jobText
    }
}

private struct ResumeUploadButton: View {
    let onDocumentPick: (URL) -> Void
    let onImagePick: (URL) -> Void

    @State private var isOptionsPresented = false
    @State private var isDocumentImporterPresented = false
    @State private var isImagePickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Button {
            isOptionsPresented = true
        } label: {
            Label("Upload Resume", systemImage: "square.and.arrow.up.fill")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.resumeBlue)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.resumeBlue.opacity(0.08), in: Capsule())
        .confirmationDialog("Upload Resume", isPresented: $isOptionsPresented, titleVisibility: .visible) {
            Button("Document") {
                isDocumentImporterPresented = true
            }
            Button("Image") {
                isImagePickerPresented = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $isDocumentImporterPresented,
            allowedContentTypes: [.pdf, .plainText, .rtf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                onDocumentPick(url)
            }
        }
        .photosPicker(
            isPresented: $isImagePickerPresented,
            selection: $selectedImageItem,
            matching: .images
        )
        .onChange(of: selectedImageItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("resume-image-\(UUID().uuidString).jpg")
                    try? data.write(to: url)
                    await MainActor.run {
                        onImagePick(url)
                        selectedImageItem = nil
                    }
                }
            }
        }
    }
}

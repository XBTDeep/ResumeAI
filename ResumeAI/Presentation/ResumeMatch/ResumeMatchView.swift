import SwiftUI

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
            HStack(spacing: 12) {
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
                    Text("Local resume matching for better applications")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.resumeMuted)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Label("Runs locally", systemImage: "lock.shield.fill")
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
        VStack(alignment: .leading, spacing: 18) {
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

            VStack(alignment: .leading, spacing: 12) {
                Text("Resume")
                    .font(.headline)
                    .foregroundStyle(Color.resumeInk)
                HStack(spacing: 10) {
                    DocumentImportButton { viewModel.attachDocument(url: $0) }
                    ImageImportButton { viewModel.attachImage(url: $0) }
                    if !viewModel.selectedResumeName.isEmpty {
                        Button("Clear") { viewModel.clearResumeAttachment() }
                            .buttonStyle(.borderless)
                    }
                }
                if !viewModel.selectedResumeName.isEmpty {
                    Label(viewModel.selectedResumeName, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.resumeTeal)
                }
                TextEditor(text: $viewModel.resumeText)
                    .focused($focusedField, equals: .resume)
                    .frame(minHeight: 124)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(Color.resumeSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if viewModel.resumeText.isEmpty {
                            Text("Or paste your resume text here...")
                                .font(.subheadline)
                                .foregroundStyle(Color.resumeMuted.opacity(0.75))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Job")
                        .font(.headline)
                        .foregroundStyle(Color.resumeInk)
                    Spacer()
                    Picker("Job input", selection: $viewModel.inputMode) {
                        ForEach(JobInputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)
                }

                if viewModel.inputMode == .url {
                    TextField("https://company.com/careers/job-posting", text: $viewModel.jobURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .jobURL)
                        .padding(15)
                        .background(Color.resumeSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    TextEditor(text: $viewModel.jobText)
                        .focused($focusedField, equals: .jobText)
                        .frame(minHeight: 124)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.resumeSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if viewModel.jobText.isEmpty {
                                Text("Paste the full job description here...")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.resumeMuted.opacity(0.75))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
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
        case resume
        case jobURL
        case jobText
    }
}

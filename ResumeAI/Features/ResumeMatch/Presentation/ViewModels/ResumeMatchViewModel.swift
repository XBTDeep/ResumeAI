import Foundation
import SwiftUI

@MainActor
final class ResumeMatchViewModel: ObservableObject {
    @Published var resumeText = ""
    @Published var jobText = ""
    @Published var jobURLText = ""
    @Published var selectedResumeName = ""
    @Published var analysis: ResumeMatchAnalysis?
    @Published var isAnalyzing = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String?
    @Published var inputMode: JobInputMode = .url

    private var resumeFileInput: ResumeInput?
    private let analyzeUseCase: AnalyzeResumeMatchUseCase

    init(analyzeUseCase: AnalyzeResumeMatchUseCase = DependencyContainer.makeAnalyzeResumeMatchUseCase()) {
        self.analyzeUseCase = analyzeUseCase
    }

    var canAnalyze: Bool {
        hasResumeInput && hasJobInput && !isAnalyzing
    }

    private var hasResumeInput: Bool {
        !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || resumeFileInput != nil
    }

    private var hasJobInput: Bool {
        switch inputMode {
        case .url:
            return URL(string: jobURLText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        case .paste:
            return !jobText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func attachDocument(url: URL) {
        resumeFileInput = .document(url)
        selectedResumeName = url.lastPathComponent
        errorMessage = nil
    }

    func attachImage(url: URL) {
        resumeFileInput = .image(url)
        selectedResumeName = url.lastPathComponent
        errorMessage = nil
    }

    func clearResumeAttachment() {
        resumeFileInput = nil
        selectedResumeName = ""
    }

    func analyze() async {
        guard !isAnalyzing else { return }
        errorMessage = nil
        analysis = nil
        isAnalyzing = true

        do {
            loadingMessage = "Reading your resume..."
            let resumeInput = makeResumeInput()

            loadingMessage = inputMode == .url ? "Opening the job link..." : "Reading the job description..."
            let jobInput = try makeJobInput()

            loadingMessage = "Comparing skills and requirements..."
            try await Task.sleep(nanoseconds: 250_000_000)

            loadingMessage = "Writing your scorecard..."
            let result = try await analyzeUseCase.execute(resumeInput: resumeInput, jobInput: jobInput)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                analysis = result
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        loadingMessage = ""
        isAnalyzing = false
    }

    private func makeResumeInput() -> ResumeInput {
        let pasted = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pasted.isEmpty { return .pastedText(pasted) }
        return resumeFileInput ?? .pastedText("")
    }

    private func makeJobInput() throws -> JobInput {
        switch inputMode {
        case .url:
            let raw = jobURLText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw) else { throw ResumeAIError.invalidJobURL }
            return .url(url)
        case .paste:
            return .pastedDescription(jobText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

enum JobInputMode: String, CaseIterable, Identifiable {
    case url = "Job Link"
    case paste = "Paste Description"

    var id: String { rawValue }
}

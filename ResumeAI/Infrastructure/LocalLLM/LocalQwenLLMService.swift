import Foundation

final class LocalQwenLLMService: ResumeSuggestionGenerating {
    private let modelFileName = "qwen2.5-0.5b-instruct-q4"

    func generateSuggestions(resume: ResumeDocument, job: JobPosting, draft: ResumeMatchDraft) async throws -> GeneratedResumeAdvice {
        // This boundary is intentionally isolated for a real llama.cpp/Core ML runner.
        // Until a GGUF runtime and model file are bundled, the app returns deterministic local advice.
        if hasBundledQwenModel {
            return generateFallbackAdvice(resume: resume, job: job, draft: draft, modelStatus: "Local Qwen model ready")
        } else {
            return generateFallbackAdvice(resume: resume, job: job, draft: draft, modelStatus: "Local analysis mode")
        }
    }

    private var hasBundledQwenModel: Bool {
        Bundle.main.url(forResource: modelFileName, withExtension: "gguf") != nil
    }

    private func generateFallbackAdvice(resume: ResumeDocument, job: JobPosting, draft: ResumeMatchDraft, modelStatus: String) -> GeneratedResumeAdvice {
        let fitBand: String
        switch draft.baseScore {
        case 85...100:
            fitBand = "Excellent fit"
        case 70..<85:
            fitBand = "Strong fit"
        case 50..<70:
            fitBand = "Moderate fit"
        default:
            fitBand = "Stretch fit"
        }

        let missing = draft.missingKeywords.prefix(5).joined(separator: ", ")
        let summary = missing.isEmpty
            ? "\(fitBand). Your resume aligns well with the role. Tighten the wording around measurable impact before applying."
            : "\(fitBand). Your resume has useful overlap, but the job emphasizes \(missing). Add truthful evidence for those areas if you have it."

        let suggestions = makeSuggestions(draft: draft)
        let rewrites = makeRewrites(resume: resume.text, missingKeywords: Array(draft.missingKeywords.prefix(4)))

        return GeneratedResumeAdvice(
            summary: "\(summary) \(modelStatus) kept everything on-device.",
            strengths: draft.strengths,
            gaps: draft.gaps,
            suggestions: suggestions,
            rewrittenBullets: rewrites
        )
    }

    private func makeSuggestions(draft: ResumeMatchDraft) -> [ResumeSuggestion] {
        var suggestions: [ResumeSuggestion] = []
        if !draft.missingKeywords.isEmpty {
            suggestions.append(ResumeSuggestion(
                title: "Mirror the role’s strongest language",
                explanation: "Add the most relevant missing terms naturally in experience bullets, especially \(draft.missingKeywords.prefix(5).joined(separator: ", ")). Only include skills you can defend in an interview.",
                priority: .high
            ))
        }
        if (draft.categories.first { $0.name == "Resume Clarity" }?.score ?? 0) < 8 {
            suggestions.append(ResumeSuggestion(
                title: "Make impact easier to scan",
                explanation: "Use short bullets with action, scope, tool, and measurable outcome. Recruiters should see the match in under 30 seconds.",
                priority: .high
            ))
        }
        suggestions.append(ResumeSuggestion(
            title: "Add one job-specific proof point",
            explanation: "Create one tailored bullet that connects your most relevant project to a responsibility in the posting.",
            priority: .medium
        ))
        suggestions.append(ResumeSuggestion(
            title: "Keep the resume honest and specific",
            explanation: "Do not stuff keywords. Tie every added term to a concrete project, result, or collaboration example.",
            priority: .medium
        ))
        return suggestions
    }

    private func makeRewrites(resume: String, missingKeywords: [String]) -> [BulletRewrite] {
        let bullets = resume
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("-") || $0.hasPrefix("•") }

        let seed = bullets.first?.trimmingCharacters(in: CharacterSet(charactersIn: "-• ")) ?? "Built and improved product features for users."
        let keywordPhrase = missingKeywords.isEmpty ? "role-specific requirements" : missingKeywords.prefix(3).joined(separator: ", ")

        return [
            BulletRewrite(
                before: seed,
                after: "Improved \(seed.lowercased()) while aligning implementation with \(keywordPhrase), increasing clarity around ownership, tools, and business impact."
            ),
            BulletRewrite(
                before: "Responsible for cross-functional technical work.",
                after: "Partnered with product, design, and engineering stakeholders to deliver production-ready improvements tied to \(keywordPhrase)."
            )
        ]
    }
}

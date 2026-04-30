import Foundation

protocol ResumeSuggestionGenerating {
    func generateSuggestions(resume: ResumeDocument, job: JobPosting, draft: ResumeMatchDraft) async throws -> GeneratedResumeAdvice
}

struct GeneratedResumeAdvice: Equatable {
    let summary: String
    let strengths: [String]
    let gaps: [String]
    let suggestions: [ResumeSuggestion]
    let rewrittenBullets: [BulletRewrite]
}

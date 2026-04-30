import Foundation

struct AnalyzeResumeMatchUseCase {
    let resumeExtractor: ResumeTextExtracting
    let jobProvider: JobDescriptionProviding
    let scoringService: ResumeScoringService
    let suggestionGenerator: ResumeSuggestionGenerating

    func execute(resumeInput: ResumeInput, jobInput: JobInput) async throws -> ResumeMatchAnalysis {
        async let resume = resumeExtractor.extractText(from: resumeInput)
        async let job = jobProvider.resolveJob(from: jobInput)
        let resolvedResume = try await resume
        let resolvedJob = try await job
        let draft = scoringService.score(resume: resolvedResume, job: resolvedJob)
        let advice = try await suggestionGenerator.generateSuggestions(resume: resolvedResume, job: resolvedJob, draft: draft)

        return ResumeMatchAnalysis(
            overallScore: draft.baseScore,
            summary: advice.summary,
            categoryScores: draft.categories,
            strengths: advice.strengths.isEmpty ? draft.strengths : advice.strengths,
            gaps: advice.gaps.isEmpty ? draft.gaps : advice.gaps,
            suggestions: advice.suggestions,
            rewrittenBullets: advice.rewrittenBullets,
            matchedKeywords: draft.matchedKeywords,
            missingKeywords: draft.missingKeywords
        )
    }
}

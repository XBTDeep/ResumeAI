import Foundation

struct DependencyContainer {
    static func makeAnalyzeResumeMatchUseCase() -> AnalyzeResumeMatchUseCase {
        AnalyzeResumeMatchUseCase(
            resumeExtractor: ResumeTextExtractionRepository(),
            jobProvider: JobDescriptionRepository(),
            scoringService: ResumeScoringService(),
            suggestionGenerator: LocalQwenSuggestionService()
        )
    }
}

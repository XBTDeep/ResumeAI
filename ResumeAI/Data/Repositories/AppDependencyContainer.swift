import Foundation

struct AppDependencyContainer {
    static func makeAnalyzeResumeMatchUseCase() -> AnalyzeResumeMatchUseCase {
        AnalyzeResumeMatchUseCase(
            resumeExtractor: ResumeTextExtractionRepository(),
            jobProvider: JobDescriptionRepository(),
            scoringService: ResumeScoringService(),
            suggestionGenerator: LocalQwenLLMService()
        )
    }
}

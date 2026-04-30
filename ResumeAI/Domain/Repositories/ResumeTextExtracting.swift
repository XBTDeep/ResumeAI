import Foundation

protocol ResumeTextExtracting {
    func extractText(from input: ResumeInput) async throws -> ResumeDocument
}

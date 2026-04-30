import Foundation

struct ResumeDocument: Equatable {
    let text: String
    let sourceName: String
}

struct JobPosting: Equatable {
    let text: String
    let source: JobSource
}

enum JobSource: Equatable {
    case pasted
    case url(URL)
}

enum ResumeInput: Equatable {
    case pastedText(String)
    case document(URL)
    case image(URL)
}

enum JobInput: Equatable {
    case pastedDescription(String)
    case url(URL)
}

struct ResumeMatchAnalysis: Equatable {
    let overallScore: Int
    let summary: String
    let categoryScores: [ScoreCategory]
    let strengths: [String]
    let gaps: [String]
    let suggestions: [ResumeSuggestion]
    let rewrittenBullets: [BulletRewrite]
    let matchedKeywords: [String]
    let missingKeywords: [String]
}

struct ScoreCategory: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let score: Int
    let maxScore: Int

    var percentage: Double {
        guard maxScore > 0 else { return 0 }
        return Double(score) / Double(maxScore)
    }
}

struct ResumeSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let explanation: String
    let priority: SuggestionPriority
}

enum SuggestionPriority: String, Equatable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct BulletRewrite: Identifiable, Equatable {
    let id = UUID()
    let before: String
    let after: String
}

struct ResumeMatchDraft: Equatable {
    let baseScore: Int
    let categories: [ScoreCategory]
    let matchedKeywords: [String]
    let missingKeywords: [String]
    let strengths: [String]
    let gaps: [String]
}

import Foundation

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

struct ResumeMatchDraft: Equatable {
    let baseScore: Int
    let categories: [ScoreCategory]
    let matchedKeywords: [String]
    let missingKeywords: [String]
    let strengths: [String]
    let gaps: [String]
}

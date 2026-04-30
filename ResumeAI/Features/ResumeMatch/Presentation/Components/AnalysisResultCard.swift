import SwiftUI

struct AnalysisResultCard: View {
    let analysis: ResumeMatchAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AnalysisSummarySection(
                score: analysis.overallScore,
                verdict: verdict,
                summary: analysis.summary
            )
            ScoreResultSection(categories: analysis.categoryScores)
            KeywordSignalsSection(
                matchedKeywords: analysis.matchedKeywords,
                missingKeywords: analysis.missingKeywords
            )
            InsightSection(
                title: "Strengths",
                icon: "checkmark.seal.fill",
                items: analysis.strengths,
                color: .resumeTeal
            )
            InsightSection(
                title: "Gaps",
                icon: "exclamationmark.triangle.fill",
                items: analysis.gaps,
                color: .orange
            )
            SuggestionSection(suggestions: analysis.suggestions)
            RewriteSection(rewrites: analysis.rewrittenBullets)
        }
    }

    private var verdict: String {
        switch analysis.overallScore {
        case 85...100: return "Excellent fit"
        case 70..<85: return "Strong fit"
        case 50..<70: return "Worth tailoring"
        default: return "Stretch role"
        }
    }
}

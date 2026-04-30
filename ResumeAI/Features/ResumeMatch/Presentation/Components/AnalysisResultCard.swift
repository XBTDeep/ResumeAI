import SwiftUI

struct AnalysisResultCard: View {
    let analysis: ResumeMatchAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 18) {
                ScoreRingView(score: analysis.overallScore)
                VStack(alignment: .leading, spacing: 8) {
                    Text(verdict)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.resumeInk)
                    Text(analysis.summary)
                        .font(.callout)
                        .foregroundStyle(Color.resumeMuted)
                        .lineSpacing(3)
                }
            }

            ScoreBreakdownView(categories: analysis.categoryScores)

            KeywordCloudView(title: "Matched Signals", keywords: analysis.matchedKeywords, tint: .resumeTeal)
            KeywordCloudView(title: "Gaps To Address", keywords: analysis.missingKeywords, tint: .orange)

            InsightSection(title: "Strengths", icon: "checkmark.seal.fill", items: analysis.strengths, color: .resumeTeal)
            InsightSection(title: "Gaps", icon: "exclamationmark.triangle.fill", items: analysis.gaps, color: .orange)
            SuggestionSection(suggestions: analysis.suggestions)
            RewriteSection(rewrites: analysis.rewrittenBullets)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.resumeBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 16)
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

struct InsightSection: View {
    let title: String
    let icon: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Color.resumeInk)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(color).frame(width: 7, height: 7).padding(.top, 7)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(Color.resumeMuted)
                        .lineSpacing(2)
                }
            }
        }
    }
}

struct SuggestionSection: View {
    let suggestions: [ResumeSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggestions", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Color.resumeInk)
            ForEach(suggestions) { suggestion in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.resumeInk)
                        Spacer()
                        Text(suggestion.priority.rawValue)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(priorityColor(suggestion.priority).opacity(0.14), in: Capsule())
                            .foregroundStyle(priorityColor(suggestion.priority))
                    }
                    Text(suggestion.explanation)
                        .font(.subheadline)
                        .foregroundStyle(Color.resumeMuted)
                }
                .padding(14)
                .background(Color.resumeSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func priorityColor(_ priority: SuggestionPriority) -> Color {
        switch priority {
        case .high: return .orange
        case .medium: return .resumeBlue
        case .low: return .resumeMuted
        }
    }
}

struct RewriteSection: View {
    let rewrites: [BulletRewrite]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bullet Rewrites", systemImage: "pencil.and.outline")
                .font(.headline)
                .foregroundStyle(Color.resumeInk)
            ForEach(rewrites) { rewrite in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Before")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.resumeMuted)
                    Text(rewrite.before)
                        .font(.subheadline)
                        .foregroundStyle(Color.resumeMuted)
                    Divider()
                    Text("After")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.resumeBlue)
                    Text(rewrite.after)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.resumeInk)
                }
                .padding(14)
                .background(Color.resumeBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

struct KeywordCloudView: View {
    let title: String
    let keywords: [String]
    let tint: Color

    var body: some View {
        if !keywords.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.resumeInk)
                FlowLayout(spacing: 8) {
                    ForEach(keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(tint.opacity(0.12), in: Capsule())
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }
}

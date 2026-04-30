import SwiftUI

struct ResultSectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.resumeBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

struct AnalysisSummarySection: View {
    let score: Int
    let verdict: String
    let summary: String

    var body: some View {
        ResultSectionCard {
            HStack(alignment: .center, spacing: 18) {
                ScoreRingView(score: score)
                VStack(alignment: .leading, spacing: 8) {
                    Text(verdict)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.resumeInk)
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(Color.resumeMuted)
                        .lineSpacing(3)
                }
            }
        }
    }
}

struct ScoreResultSection: View {
    let categories: [ScoreCategory]

    var body: some View {
        ResultSectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Score Breakdown", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Color.resumeInk)
                ScoreBreakdownView(categories: categories)
            }
        }
    }
}

struct KeywordSignalsSection: View {
    let matchedKeywords: [String]
    let missingKeywords: [String]

    var body: some View {
        if !matchedKeywords.isEmpty || !missingKeywords.isEmpty {
            ResultSectionCard {
                VStack(alignment: .leading, spacing: 16) {
                    KeywordCloudView(title: "Matched Signals", keywords: matchedKeywords, tint: .resumeTeal)
                    KeywordCloudView(title: "Gaps To Address", keywords: missingKeywords, tint: .orange)
                }
            }
        }
    }
}

struct InsightSection: View {
    let title: String
    let icon: String
    let items: [String]
    let color: Color

    var body: some View {
        if !items.isEmpty {
            ResultSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(title, systemImage: icon)
                        .font(.headline)
                        .foregroundStyle(Color.resumeInk)
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(color)
                                .frame(width: 7, height: 7)
                                .padding(.top, 7)
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(Color.resumeMuted)
                                .lineSpacing(2)
                        }
                    }
                }
            }
        }
    }
}

struct SuggestionSection: View {
    let suggestions: [ResumeSuggestion]

    var body: some View {
        if !suggestions.isEmpty {
            ResultSectionCard {
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
                        .background(Color.resumeSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
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
        if !rewrites.isEmpty {
            ResultSectionCard {
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
                        .background(Color.resumeBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
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

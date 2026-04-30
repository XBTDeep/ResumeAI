import SwiftUI

struct ScoreBreakdownView: View {
    let categories: [ScoreCategory]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(categories) { category in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.resumeInk)
                        Spacer()
                        Text("\(category.score)/\(category.maxScore)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.resumeBlue)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.resumeBorder)
                            Capsule()
                                .fill(LinearGradient(colors: [.resumeBlue, .resumeTeal], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * category.percentage)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}

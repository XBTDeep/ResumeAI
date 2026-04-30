import SwiftUI

struct ScoreRingView: View {
    let score: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.resumeBorder, lineWidth: 16)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    AngularGradient(colors: [.resumeBlue, .resumeTeal, .resumeBlue], center: .center),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(score)%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.resumeInk)
                Text("Match")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.resumeMuted)
            }
        }
        .frame(width: 132, height: 132)
        .accessibilityLabel("Overall match score \(score) percent")
    }
}

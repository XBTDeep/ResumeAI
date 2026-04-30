import Foundation

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

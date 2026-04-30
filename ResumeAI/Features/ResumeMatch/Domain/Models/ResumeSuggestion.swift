import Foundation

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

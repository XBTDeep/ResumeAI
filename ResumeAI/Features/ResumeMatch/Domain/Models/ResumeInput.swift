import Foundation

enum ResumeInput: Equatable {
    case pastedText(String)
    case document(URL)
    case image(URL)
}

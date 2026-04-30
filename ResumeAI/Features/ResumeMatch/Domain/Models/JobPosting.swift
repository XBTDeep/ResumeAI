import Foundation

struct JobPosting: Equatable {
    let text: String
    let source: JobSource
}

enum JobSource: Equatable {
    case pasted
    case url(URL)
}

enum JobInput: Equatable {
    case pastedDescription(String)
    case url(URL)
}

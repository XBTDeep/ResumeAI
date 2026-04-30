import Foundation

enum ResumeAIError: LocalizedError {
    case emptyResume
    case emptyJobDescription
    case unreadableResume
    case unsupportedResumeFormat
    case invalidJobURL
    case blockedJobPage
    case jobDescriptionTooShort

    var errorDescription: String? {
        switch self {
        case .emptyResume:
            return "Paste your resume or upload a document/image before analyzing."
        case .emptyJobDescription:
            return "Add a job link or paste a job description before analyzing."
        case .unreadableResume:
            return "I couldn’t read this resume. Try a PDF, image, TXT/RTF file, or paste the text directly."
        case .unsupportedResumeFormat:
            return "This resume format is not supported yet. Try PDF, image, TXT, RTF, or pasted text."
        case .invalidJobURL:
            return "That job link does not look valid. Paste the job description if the page is private or blocked."
        case .blockedJobPage:
            return "This job page blocked automatic reading. Paste the description and I’ll analyze it."
        case .jobDescriptionTooShort:
            return "I couldn’t find enough job description text at that link. Paste the posting here instead."
        }
    }
}

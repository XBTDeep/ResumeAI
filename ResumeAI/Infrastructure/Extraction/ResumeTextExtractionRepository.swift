import Foundation
import PDFKit
import UIKit
import Vision

final class ResumeTextExtractionRepository: ResumeTextExtracting {
    func extractText(from input: ResumeInput) async throws -> ResumeDocument {
        switch input {
        case .pastedText(let text):
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { throw ResumeAIError.emptyResume }
            return ResumeDocument(text: cleaned, sourceName: "Pasted resume")
        case .document(let url):
            let text = try await extractDocumentText(from: url)
            return ResumeDocument(text: text, sourceName: url.lastPathComponent)
        case .image(let url):
            let text = try await extractImageText(from: url)
            return ResumeDocument(text: text, sourceName: url.lastPathComponent)
        }
    }

    private func extractDocumentText(from url: URL) async throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == "pdf" {
            guard let document = PDFDocument(url: url) else { throw ResumeAIError.unreadableResume }
            let text = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ResumeAIError.unreadableResume }
            return text
        }

        if ["txt", "md", "rtf"].contains(pathExtension) {
            let data = try Data(contentsOf: url)
            if pathExtension == "rtf",
               let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { throw ResumeAIError.unreadableResume }
                return text
            }
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let text, !text.isEmpty else { throw ResumeAIError.unreadableResume }
            return text
        }

        throw ResumeAIError.unsupportedResumeFormat
    }

    private func extractImageText(from url: URL) async throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        guard let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage else {
            throw ResumeAIError.unreadableResume
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard !text.isEmpty else {
                    continuation.resume(throwing: ResumeAIError.unreadableResume)
                    return
                }

                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

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

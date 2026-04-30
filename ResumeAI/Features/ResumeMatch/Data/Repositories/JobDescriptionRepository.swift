import Foundation

final class JobDescriptionRepository: JobDescriptionProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func resolveJob(from input: JobInput) async throws -> JobPosting {
        switch input {
        case .pastedDescription(let text):
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { throw ResumeAIError.emptyJobDescription }
            return JobPosting(text: cleaned, source: .pasted)
        case .url(let url):
            guard ["http", "https"].contains(url.scheme?.lowercased()) else {
                throw ResumeAIError.invalidJobURL
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 18
            request.setValue("Mozilla/5.0 ResumeAI/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ResumeAIError.blockedJobPage
            }
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                throw ResumeAIError.jobDescriptionTooShort
            }
            let text = extractReadableText(from: html)
            guard text.count > 300 else { throw ResumeAIError.jobDescriptionTooShort }
            return JobPosting(text: text, source: .url(url))
        }
    }

    private func extractReadableText(from html: String) -> String {
        var output = html
        let patterns = [
            #"<script[\s\S]*?</script>"#,
            #"<style[\s\S]*?</style>"#,
            #"<nav[\s\S]*?</nav>"#,
            #"<footer[\s\S]*?</footer>"#,
            #"<svg[\s\S]*?</svg>"#,
            #"<!--([\s\S]*?)-->"#
        ]
        for pattern in patterns {
            output = output.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        output = output.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        output = output.replacingOccurrences(of: #"</(p|li|div|section|h1|h2|h3)>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        output = output.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        output = decodeEntities(output)
        output = output.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeEntities(_ text: String) -> String {
        var decoded = text
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&nbsp;": " "
        ]
        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }
        return decoded
    }
}

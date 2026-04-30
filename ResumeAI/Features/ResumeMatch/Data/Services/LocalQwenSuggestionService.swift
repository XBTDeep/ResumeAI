import Foundation
#if canImport(LlamaSwift)
import LlamaSwift
#endif

final class LocalQwenSuggestionService: ResumeSuggestionGenerating {
    private let modelFileName = "Qwen3.5-0.8B.q4_k_m"
    private let modelExtension = "gguf"
    private let minimumModelBytes: Int64 = 400_000_000
    private let inferenceEngine = LocalQwenInferenceEngine()

    func generateSuggestions(resume: ResumeDocument, job: JobPosting, draft: ResumeMatchDraft) async throws -> GeneratedResumeAdvice {
        let reliableAdvice = makeReliableATSAdvice(resume: resume, draft: draft)

        guard let modelURL = localQwenModelURL else {
            print("ResumeAI Local Qwen: 0.8B model missing, using reliable ATS advice.")
            return reliableAdvice
        }

        do {
            print("ResumeAI Local Qwen: loading model at \(modelURL.path)")
            let prompt = makePrompt(resume: resume, job: job, draft: draft)
            let generatedText = try await inferenceEngine.generate(prompt: prompt, modelURL: modelURL)
            print("ResumeAI Local Qwen: generated \(generatedText.count) characters")
            let qwenAdvice = try parseGeneratedAdvice(generatedText)
            return merge(reliableAdvice: reliableAdvice, qwenAdvice: qwenAdvice)
        } catch {
            print("ResumeAI Local Qwen: discarded unusable output: \(error.localizedDescription)")
            return reliableAdvice
        }
    }

    private var localQwenModelURL: URL? {
        let directBundleModelURL = Bundle.main.resourceURL?
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("\(modelFileName).\(modelExtension)")

        let bundledCandidates = [
            directBundleModelURL,
            Bundle.main.url(forResource: modelFileName, withExtension: modelExtension),
            Bundle.main.url(forResource: modelFileName, withExtension: modelExtension, subdirectory: "Models")
        ].compactMap { $0 }

        let documentsQwenModels = localDocumentsModelURLs()
        let candidates = bundledCandidates + documentsQwenModels

        return candidates.first { url in
            url.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveCompare(modelFileName) == .orderedSame
                && isUsableModelFile(at: url)
        }
    }

    private func localDocumentsModelURLs() -> [URL] {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        let modelDirectories = [
            documentsURL,
            documentsURL.appendingPathComponent("Models", isDirectory: true)
        ]

        return modelDirectories.flatMap { directory in
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        }
        .filter { $0.pathExtension.localizedCaseInsensitiveCompare(modelExtension) == .orderedSame }
    }

    private func isUsableModelFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return false
        }

        return Int64(fileSize) >= minimumModelBytes
    }

    private func makePrompt(resume: ResumeDocument, job: JobPosting, draft: ResumeMatchDraft) -> String {
        let categories = draft.categories
            .map { "- \($0.name): \($0.score)/10" }
            .joined(separator: "\n")

        return """
        You are an expert ATS and recruiter resume reviewer. Return one minified JSON object only. Do not explain your reasoning.

        Rules:
        - The first character must be { and the last character must be }.
        - Use double-quoted JSON keys and string values.
        - Required keys: summary, strengths, gaps, suggestions, rewrittenBullets.
        - strengths and gaps are arrays of strings.
        - suggestions is an array of objects with title, explanation, priority.
        - rewrittenBullets is an array of objects with before, after.
        - Treat only real skills, tools, methodologies, certifications, responsibilities, and experience requirements as ATS signals.
        - Never call the employer name, product name, recruiter name, location, salary, benefits, EEO text, department name, job title, or generic culture wording a missing skill or gap.
        - Keep suggestions truthful. Do not invent experience.
        - Every gap must be a missing role requirement that appears in the Missing keywords list or a concrete responsibility from the job posting.
        - Every suggestion must tell the candidate exactly what resume section or bullet to improve.
        - Rewritten bullets must be based on an existing resume bullet. Do not use placeholders.
        - Provide 2 to 4 suggestions and 1 to 2 rewritten bullets.

        Score: \(draft.baseScore)/100
        Category scores:
        \(categories)

        Matched keywords: \(draft.matchedKeywords.prefix(12).joined(separator: ", "))
        Missing keywords: \(draft.missingKeywords.prefix(12).joined(separator: ", "))

        Resume:
        \(resume.text.truncated(to: 3_500))

        Job posting:
        \(job.text.truncated(to: 2_500))
        """
    }

    private func parseGeneratedAdvice(_ generatedText: String) throws -> GeneratedResumeAdvice {
        guard let jsonText = generatedText.cleanedModelJSON.firstBalancedJSONObject,
              let data = jsonText.data(using: .utf8) else {
            throw LocalQwenInferenceError.invalidJSON(generatedText.visiblePreview)
        }

        let payload: QwenAdvicePayload
        do {
            payload = try JSONDecoder().decode(QwenAdvicePayload.self, from: data)
        } catch {
            throw LocalQwenInferenceError.invalidJSON("Decode failed: \(error.localizedDescription). Output: \(jsonText.visiblePreview)")
        }
        let strengths = try validated(payload.strengths, minimumCount: 1, fieldName: "strengths")
        let gaps = try validated(payload.gaps, minimumCount: 1, fieldName: "gaps")
        let suggestions: [ResumeSuggestion] = try payload.suggestions.prefix(4).map { suggestion in
            let title = try validated(suggestion.title, fieldName: "suggestion title")
            let explanation = try validated(suggestion.explanation, fieldName: "suggestion explanation")

            return ResumeSuggestion(
                title: title,
                explanation: explanation,
                priority: SuggestionPriority(rawValue: suggestion.priority.capitalized) ?? .medium
            )
        }

        let rewrites: [BulletRewrite] = try payload.rewrittenBullets.prefix(2).map { rewrite in
            let before = try validated(rewrite.before, fieldName: "rewrite before")
            let after = try validated(rewrite.after, fieldName: "rewrite after")

            return BulletRewrite(
                before: before,
                after: after
            )
        }

        guard suggestions.count >= 2 else {
            throw LocalQwenInferenceError.invalidAdvice("Expected at least 2 usable suggestions.")
        }

        guard !rewrites.isEmpty else {
            throw LocalQwenInferenceError.invalidAdvice("Expected at least 1 usable bullet rewrite.")
        }

        return GeneratedResumeAdvice(
            summary: try validated(payload.summary, fieldName: "summary"),
            strengths: strengths,
            gaps: gaps,
            suggestions: Array(suggestions),
            rewrittenBullets: Array(rewrites)
        )
    }

    private func validated(_ value: String, fieldName: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let invalidFragments = ["placeholder", "existing or representative", "rewrite this bullet", "n/a", "none", "lorem ipsum"]

        guard trimmed.count >= 12, !invalidFragments.contains(where: { lowercased.contains($0) }) else {
            throw LocalQwenInferenceError.invalidAdvice("Qwen returned unusable \(fieldName).")
        }

        return trimmed
    }

    private func validated(_ values: [String], minimumCount: Int, fieldName: String) throws -> [String] {
        let validValues = Array(values.compactMap { try? validated($0, fieldName: fieldName) }.prefix(4))

        guard validValues.count >= minimumCount else {
            throw LocalQwenInferenceError.invalidAdvice("Qwen returned too few usable \(fieldName).")
        }

        return validValues
    }

    private func makeReliableATSAdvice(resume: ResumeDocument, draft: ResumeMatchDraft) -> GeneratedResumeAdvice {
        let missingKeywords = Array(draft.missingKeywords.prefix(6))
        let matchedKeywords = Array(draft.matchedKeywords.prefix(6))
        let fitBand: String

        switch draft.baseScore {
        case 85...100:
            fitBand = "Excellent ATS fit"
        case 70..<85:
            fitBand = "Strong ATS fit"
        case 50..<70:
            fitBand = "Moderate ATS fit"
        default:
            fitBand = "Stretch ATS fit"
        }

        let summary = makeReliableSummary(fitBand: fitBand, matchedKeywords: matchedKeywords, missingKeywords: missingKeywords)
        let strengths = sanitizedList(draft.strengths, fallback: makeReliableStrengths(matchedKeywords: matchedKeywords))
        let gaps = sanitizedList(draft.gaps, fallback: makeReliableGaps(missingKeywords: missingKeywords))
        let suggestions = makeReliableSuggestions(draft: draft, matchedKeywords: matchedKeywords, missingKeywords: missingKeywords)
        let rewrites = makeReliableRewrites(resumeText: resume.text, missingKeywords: missingKeywords)

        return GeneratedResumeAdvice(
            summary: summary,
            strengths: strengths,
            gaps: gaps,
            suggestions: suggestions,
            rewrittenBullets: rewrites
        )
    }

    private func merge(reliableAdvice: GeneratedResumeAdvice, qwenAdvice: GeneratedResumeAdvice) -> GeneratedResumeAdvice {
        GeneratedResumeAdvice(
            summary: polishedSummary(qwenAdvice.summary) ?? reliableAdvice.summary,
            strengths: reliableAdvice.strengths,
            gaps: reliableAdvice.gaps,
            suggestions: reliableAdvice.suggestions,
            rewrittenBullets: reliableAdvice.rewrittenBullets
        )
    }

    private func makeReliableSummary(fitBand: String, matchedKeywords: [String], missingKeywords: [String]) -> String {
        let matchedPhrase = matchedKeywords.isEmpty ? "some role requirements" : matchedKeywords.prefix(4).joined(separator: ", ")
        guard !missingKeywords.isEmpty else {
            return "\(fitBand). The resume already aligns with the main ATS signals, especially \(matchedPhrase). Before applying, make the strongest achievements easier to scan with clear metrics and role-specific wording."
        }

        return "\(fitBand). The resume shows overlap around \(matchedPhrase), but the ATS match will improve if the resume adds truthful evidence for \(missingKeywords.prefix(4).joined(separator: ", "))."
    }

    private func makeReliableStrengths(matchedKeywords: [String]) -> [String] {
        guard !matchedKeywords.isEmpty else {
            return ["The resume has enough relevant experience to tailor toward the posting."]
        }

        return [
            "The resume already includes relevant ATS signals such as \(matchedKeywords.prefix(5).joined(separator: ", ")).",
            "The current content gives you a usable base for a targeted application."
        ]
    }

    private func makeReliableGaps(missingKeywords: [String]) -> [String] {
        guard !missingKeywords.isEmpty else {
            return ["No major missing skill signals were detected; the next improvement is stronger proof and metrics."]
        }

        return [
            "The resume does not clearly show evidence for \(missingKeywords.prefix(5).joined(separator: ", ")).",
            "Add those terms only where you can tie them to a real project, responsibility, or measurable result."
        ]
    }

    private func makeReliableSuggestions(draft: ResumeMatchDraft, matchedKeywords: [String], missingKeywords: [String]) -> [ResumeSuggestion] {
        var suggestions: [ResumeSuggestion] = []

        if !missingKeywords.isEmpty {
            suggestions.append(ResumeSuggestion(
                title: "Add missing skill evidence",
                explanation: "Work \(missingKeywords.prefix(5).joined(separator: ", ")) into your experience or projects only where you can support them with real work.",
                priority: .high
            ))
        }

        if !matchedKeywords.isEmpty {
            suggestions.append(ResumeSuggestion(
                title: "Move strongest matches higher",
                explanation: "Make \(matchedKeywords.prefix(4).joined(separator: ", ")) visible in the top third of the resume so recruiters and ATS parsing see the fit quickly.",
                priority: .high
            ))
        }

        if (draft.categories.first { $0.name == "Resume Clarity" }?.score ?? 0) < 8 {
            suggestions.append(ResumeSuggestion(
                title: "Tighten bullet structure",
                explanation: "Use bullets with action, technical scope, tool or skill, and measurable outcome. Keep each bullet focused on one achievement.",
                priority: .medium
            ))
        }

        suggestions.append(ResumeSuggestion(
            title: "Quantify impact",
            explanation: "Add numbers for scale, speed, quality, revenue, users, automation, or reliability wherever the result is true and defensible.",
            priority: .medium
        ))

        return Array(suggestions.prefix(4))
    }

    private func makeReliableRewrites(resumeText: String, missingKeywords: [String]) -> [BulletRewrite] {
        let bullets = extractBullets(from: resumeText)
        let focus = missingKeywords.isEmpty ? "the role's core requirements" : missingKeywords.prefix(3).joined(separator: ", ")

        if bullets.isEmpty {
            return [
                BulletRewrite(
                    before: "Add a bullet for your most relevant project or role.",
                    after: "Delivered a relevant project using \(focus), clearly stating your ownership, technical scope, and measurable outcome."
                )
            ]
        }

        return bullets.prefix(2).map { bullet in
            let cleaned = cleanedBulletForRewrite(bullet)
            return BulletRewrite(
                before: cleaned,
                after: "\(cleaned), with clearer emphasis on \(focus), ownership, and measurable impact."
            )
        }
    }

    private func cleanedBulletForRewrite(_ bullet: String) -> String {
        bullet
            .trimmingCharacters(in: CharacterSet(charactersIn: "-•* \t\n\r"))
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:\n\r\t"))
    }

    private func extractBullets(from resumeText: String) -> [String] {
        resumeText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                line.hasPrefix("-") || line.hasPrefix("•") || line.hasPrefix("*")
            }
            .filter { $0.count >= 24 }
    }

    private func sanitizedList(_ values: [String], fallback: [String]) -> [String] {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !$0.lowercased().contains("company name") }
            .filter { !$0.lowercased().contains("employer name") }

        return cleaned.isEmpty ? fallback : Array(cleaned.prefix(4))
    }

    private func polishedSummary(_ summary: String) -> String? {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40, trimmed.count <= 420 else { return nil }
        let lowercased = trimmed.lowercased()
        let invalidFragments = ["placeholder", "lorem ipsum", "as an ai", "i cannot", "json", "```"]
        guard !invalidFragments.contains(where: { lowercased.contains($0) }) else { return nil }
        return trimmed
    }
}

private struct QwenAdvicePayload: Decodable {
    let summary: String
    let strengths: [String]
    let gaps: [String]
    let suggestions: [QwenSuggestionPayload]
    let rewrittenBullets: [QwenBulletRewritePayload]

    enum CodingKeys: String, CodingKey {
        case summary
        case strengths
        case gaps
        case suggestions
        case rewrittenBullets
        case rewrittenBulletsSnake = "rewritten_bullets"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = container.decodeFlexibleString(forKey: .summary)
        strengths = container.decodeFlexibleStringArray(forKey: .strengths)
        gaps = container.decodeFlexibleStringArray(forKey: .gaps)
        suggestions = try container.decodeIfPresent([QwenSuggestionPayload].self, forKey: .suggestions) ?? []
        rewrittenBullets = try container.decodeIfPresent([QwenBulletRewritePayload].self, forKey: .rewrittenBullets)
            ?? container.decodeIfPresent([QwenBulletRewritePayload].self, forKey: .rewrittenBulletsSnake)
            ?? []
    }
}

private struct QwenSuggestionPayload: Decodable {
    let title: String
    let explanation: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case title
        case heading
        case explanation
        case advice
        case priority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decodeFlexibleString(forKey: .title).nonEmpty
            ?? container.decodeFlexibleString(forKey: .heading).nonEmpty
            ?? ""
        explanation = container.decodeFlexibleString(forKey: .explanation).nonEmpty
            ?? container.decodeFlexibleString(forKey: .advice).nonEmpty
            ?? ""
        priority = container.decodeFlexibleString(forKey: .priority).nonEmpty ?? "medium"
    }
}

private struct QwenBulletRewritePayload: Decodable {
    let before: String
    let after: String

    enum CodingKeys: String, CodingKey {
        case before
        case original
        case current
        case after
        case rewrite
        case rewritten
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        before = container.decodeFlexibleString(forKey: .before).nonEmpty
            ?? container.decodeFlexibleString(forKey: .original).nonEmpty
            ?? container.decodeFlexibleString(forKey: .current).nonEmpty
            ?? ""
        after = container.decodeFlexibleString(forKey: .after).nonEmpty
            ?? container.decodeFlexibleString(forKey: .rewrite).nonEmpty
            ?? container.decodeFlexibleString(forKey: .rewritten).nonEmpty
            ?? ""
    }
}

private struct FlexibleString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = String(value)
        } else if let value = try? container.decode(Double.self) {
            self.value = String(value)
        } else if let value = try? container.decode(Bool.self) {
            self.value = String(value)
        } else {
            self.value = ""
        }
    }
}

private enum LocalQwenInferenceError: LocalizedError {
    case modelNotFound
    case runtimeUnavailable
    case modelLoadFailed
    case contextLoadFailed
    case promptTooLarge
    case tokenizationFailed
    case decodeFailed
    case logitsUnavailable
    case invalidJSON(String)
    case invalidAdvice(String)
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Qwen3.5 0.8B GGUF was not found. Add Qwen3.5-0.8B.q4_k_m.gguf to Resources/Models or the app Documents/Models folder."
        case .runtimeUnavailable:
            return "llama.cpp runtime is unavailable."
        case .modelLoadFailed:
            return "Qwen model could not be loaded."
        case .contextLoadFailed:
            return "Qwen context could not be created."
        case .promptTooLarge:
            return "The resume and job prompt is too large for the local context."
        case .tokenizationFailed:
            return "Qwen could not tokenize the prompt."
        case .decodeFailed:
            return "Qwen inference failed while decoding."
        case .logitsUnavailable:
            return "Qwen did not return logits for sampling."
        case .invalidJSON(let preview):
            return "Qwen did not return valid advice JSON. Output started with: \(preview)"
        case .invalidAdvice(let message):
            return message
        case .inferenceFailed(let message):
            return "Local Qwen inference failed: \(message)"
        }
    }
}

private actor LocalQwenInferenceEngine {
    private let maxGeneratedTokens = 520
    private let contextLength: Int32 = 4096
    private let batchSize: Int32 = 4096

    func generate(prompt: String, modelURL: URL) async throws -> String {
        #if canImport(LlamaSwift)
        _ = LlamaBackend.shared

        var modelParams = llama_model_default_params()
        modelParams.use_mmap = true

        guard let model = llama_model_load_from_file(modelURL.path, modelParams) else {
            throw LocalQwenInferenceError.modelLoadFailed
        }
        defer { llama_model_free(model) }

        let vocab = llama_model_get_vocab(model)
        let formattedPrompt = chatPrompt(for: prompt)
        let promptTokens = try tokenize(formattedPrompt, vocab: vocab)

        guard promptTokens.count < Int(contextLength), promptTokens.count <= Int(batchSize) else {
            throw LocalQwenInferenceError.promptTooLarge
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(contextLength)
        contextParams.n_batch = UInt32(batchSize)

        guard let context = llama_init_from_model(model, contextParams) else {
            throw LocalQwenInferenceError.contextLoadFailed
        }
        defer { llama_free(context) }

        var batch = llama_batch_init(batchSize, 0, 1)
        defer { llama_batch_free(batch) }

        guard let sampler = llama_sampler_init_greedy() else {
            throw LocalQwenInferenceError.decodeFailed
        }
        defer { llama_sampler_free(sampler) }

        try decodePrompt(promptTokens, batch: &batch, context: context)

        var generatedText = ""
        var currentPosition = Int32(promptTokens.count)

        for _ in 0..<maxGeneratedTokens {
            let nextToken = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
            llama_sampler_accept(sampler, nextToken)

            if llama_vocab_is_eog(vocab, nextToken) {
                break
            }

            let piece = tokenText(nextToken, vocab: vocab)
            generatedText += piece
            if generatedText.contains("<|im_end|>") {
                break
            }
            if generatedText.last == "}", generatedText.cleanedModelJSON.firstBalancedJSONObject != nil {
                break
            }

            prepareSingleTokenBatch(&batch, token: nextToken, position: currentPosition)
            currentPosition += 1

            guard llama_decode(context, batch) == 0 else {
                throw LocalQwenInferenceError.decodeFailed
            }
        }

        return generatedText.replacingOccurrences(of: "<|im_end|>", with: "")
        #else
        throw LocalQwenInferenceError.runtimeUnavailable
        #endif
    }

    #if canImport(LlamaSwift)
    private func chatPrompt(for prompt: String) -> String {
        """
        <|im_start|>system
        You are Qwen, running locally inside an iOS resume matching app. You return compact valid JSON only.<|im_end|>
        <|im_start|>user
        \(prompt)<|im_end|>
        <|im_start|>assistant
        """
    }

    private func tokenize(_ prompt: String, vocab: OpaquePointer?) throws -> [llama_token] {
        let maxTokenCount = prompt.utf8.count + 16
        var tokens = [llama_token](repeating: 0, count: maxTokenCount)
        let tokenCount = llama_tokenize(
            vocab,
            prompt,
            Int32(prompt.utf8.count),
            &tokens,
            Int32(maxTokenCount),
            true,
            true
        )

        guard tokenCount > 0 else {
            throw LocalQwenInferenceError.tokenizationFailed
        }

        return Array(tokens.prefix(Int(tokenCount)))
    }

    private func decodePrompt(_ tokens: [llama_token], batch: inout llama_batch, context: OpaquePointer?) throws {
        batch.n_tokens = Int32(tokens.count)

        for index in 0..<tokens.count {
            batch.token[index] = tokens[index]
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.logits[index] = 0

            if let seqIDs = batch.seq_id, let seqID = seqIDs[index] {
                seqID[0] = 0
            }
        }

        batch.logits[tokens.count - 1] = 1

        guard llama_decode(context, batch) == 0 else {
            throw LocalQwenInferenceError.decodeFailed
        }
    }

    private func prepareSingleTokenBatch(_ batch: inout llama_batch, token: llama_token, position: Int32) {
        batch.n_tokens = 1
        batch.token[0] = token
        batch.pos[0] = position
        batch.n_seq_id[0] = 1
        batch.logits[0] = 1

        if let seqIDs = batch.seq_id, let seqID = seqIDs[0] {
            seqID[0] = 0
        }
    }

    private func tokenText(_ token: llama_token, vocab: OpaquePointer?) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        let length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)

        if length > 0 {
            let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
            return String(bytes: bytes, encoding: .utf8) ?? ""
        }

        if length < 0 {
            var expandedBuffer = [CChar](repeating: 0, count: Int(-length))
            let expandedLength = llama_token_to_piece(vocab, token, &expandedBuffer, Int32(expandedBuffer.count), 0, false)
            guard expandedLength > 0 else { return "" }
            let bytes = expandedBuffer.prefix(Int(expandedLength)).map { UInt8(bitPattern: $0) }
            return String(bytes: bytes, encoding: .utf8) ?? ""
        }

        return ""
    }
    #endif
}

#if canImport(LlamaSwift)
private final class LlamaBackend {
    static let shared = LlamaBackend()

    private init() {
        llama_backend_init()
    }

    deinit {
        llama_backend_free()
    }
}
#endif

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) -> String {
        (try? decode(FlexibleString.self, forKey: key).value) ?? ""
    }

    func decodeFlexibleStringArray(forKey key: Key) -> [String] {
        if let values = try? decode([FlexibleString].self, forKey: key) {
            return values.map(\.value).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        if let value = try? decode(FlexibleString.self, forKey: key).value {
            return value
                .split(whereSeparator: { $0 == "\n" || $0 == ";" })
                .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: " -•\t")) }
                .filter { !$0.isEmpty }
        }

        return []
    }
}

private extension String {
    func truncated(to limit: Int) -> String {
        guard count > limit else { return self }
        return String(prefix(limit)) + "\n[truncated]"
    }

    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var cleanedModelJSON: String {
        var cleaned = replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|endoftext|>", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        cleaned = cleaned.replacingOccurrences(
            of: #",\s*([}\]])"#,
            with: "$1",
            options: .regularExpression
        )
        return cleaned
    }

    var firstBalancedJSONObject: String? {
        guard let start = firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var isInsideString = false
        var isEscaped = false
        var index = start

        while index < endIndex {
            let character = self[index]

            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isInsideString.toggle()
            } else if !isInsideString {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(self[start...index])
                    }
                }
            }

            index = self.index(after: index)
        }

        return nil
    }

    var visiblePreview: String {
        let compacted = replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = compacted.isEmpty ? "<empty>" : compacted
        return String(preview.prefix(240))
    }
}

import Foundation

struct ResumeScoringService {
    private let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "you", "your", "are", "will", "have", "has", "our", "their", "they", "job", "role", "work", "team", "experience", "candidate", "preferred", "required", "requirements", "responsibilities", "ability", "using", "into", "about", "within", "across", "strong", "excellent", "including", "such", "etc", "can", "all", "any", "who", "what", "when", "where", "how", "why", "but", "not", "was", "were", "been", "being", "than", "then", "them", "his", "her", "its", "per", "via"
    ]

    private let technicalSkillHints: Set<String> = [
        "swift", "swiftui", "ios", "xcode", "uikit", "combine", "async", "api", "rest", "graphql", "aws", "azure", "gcp", "docker", "kubernetes", "ci", "cd", "github", "actions", "jenkins", "sql", "postgres", "mysql", "mongodb", "firebase", "coredata", "python", "java", "javascript", "typescript", "react", "node", "cloud", "security", "testing", "analytics", "observability", "datadog", "splunk", "figma", "agile", "scrum", "leadership", "architecture", "mvvm", "clean", "ocr", "vision", "pdf"
    ]

    func score(resume: ResumeDocument, job: JobPosting) -> ResumeMatchDraft {
        let resumeTerms = weightedTerms(from: resume.text)
        let jobTerms = weightedTerms(from: job.text)
        let jobKeywords = extractKeywords(from: jobTerms)
        let resumeKeywordSet = Set(extractKeywords(from: resumeTerms))

        let matched = jobKeywords.filter { resumeKeywordSet.contains($0) }
        let missing = jobKeywords.filter { !resumeKeywordSet.contains($0) }

        let keywordScore = normalizedScore(matched: matched.count, total: max(jobKeywords.count, 1), max: 10)
        let requiredScore = scoreRequiredSignals(resumeTerms: resumeTerms, jobTerms: jobTerms)
        let seniorityScore = scoreSeniority(resume: resume.text, job: job.text)
        let clarityScore = scoreResumeClarity(resume.text)
        let experienceScore = scoreExperience(resume: resume.text, job: job.text, matchedKeywords: matched)

        let weightedOverall = Int(round(
            Double(keywordScore) * 2.0 +
            Double(requiredScore) * 2.6 +
            Double(experienceScore) * 2.2 +
            Double(seniorityScore) * 1.5 +
            Double(clarityScore) * 1.7
        ))

        let categories = [
            ScoreCategory(name: "Required Skills", score: requiredScore, maxScore: 10),
            ScoreCategory(name: "Experience Match", score: experienceScore, maxScore: 10),
            ScoreCategory(name: "Keyword Alignment", score: keywordScore, maxScore: 10),
            ScoreCategory(name: "Seniority Fit", score: seniorityScore, maxScore: 10),
            ScoreCategory(name: "Resume Clarity", score: clarityScore, maxScore: 10)
        ]

        return ResumeMatchDraft(
            baseScore: min(max(weightedOverall, 0), 100),
            categories: categories,
            matchedKeywords: Array(matched.prefix(16)),
            missingKeywords: Array(missing.prefix(16)),
            strengths: makeStrengths(matched: matched, categories: categories),
            gaps: makeGaps(missing: missing, categories: categories)
        )
    }

    private func weightedTerms(from text: String) -> [String: Int] {
        let words = text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9+#. ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }

        return words.reduce(into: [:]) { counts, word in
            counts[word, default: 0] += technicalSkillHints.contains(word) ? 3 : 1
        }
    }

    private func extractKeywords(from terms: [String: Int]) -> [String] {
        terms.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        .prefix(28)
        .map(\.key)
    }

    private func normalizedScore(matched: Int, total: Int, max: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(max, Int(round(Double(matched) / Double(total) * Double(max))))
    }

    private func scoreRequiredSignals(resumeTerms: [String: Int], jobTerms: [String: Int]) -> Int {
        let requiredSignals = technicalSkillHints.filter { jobTerms[$0] != nil }
        guard !requiredSignals.isEmpty else { return 7 }
        let hits = requiredSignals.filter { resumeTerms[$0] != nil }.count
        return max(3, normalizedScore(matched: hits, total: requiredSignals.count, max: 10))
    }

    private func scoreSeniority(resume: String, job: String) -> Int {
        let resumeLower = resume.lowercased()
        let jobLower = job.lowercased()
        let seniorWords = ["senior", "lead", "principal", "staff", "mentor", "architecture", "strategy"]
        let juniorWords = ["junior", "entry", "intern", "graduate", "associate"]
        let jobSenior = seniorWords.contains { jobLower.contains($0) }
        let resumeSenior = seniorWords.contains { resumeLower.contains($0) }
        let jobJunior = juniorWords.contains { jobLower.contains($0) }
        let resumeJunior = juniorWords.contains { resumeLower.contains($0) }

        if jobSenior && resumeSenior { return 9 }
        if jobSenior && !resumeSenior { return 6 }
        if jobJunior && resumeSenior { return 7 }
        if jobJunior && resumeJunior { return 9 }
        return 8
    }

    private func scoreResumeClarity(_ resume: String) -> Int {
        let lines = resume.split(separator: "\n").map(String.init)
        let bulletLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") || $0.contains("•") }
        let hasMetrics = resume.range(of: #"\d+%|\$\d+|\d+x|\d+ users|\d+ customers"#, options: .regularExpression) != nil
        let hasSections = ["experience", "skills", "education", "projects"].filter { resume.lowercased().contains($0) }.count
        var score = 5
        if bulletLines.count >= 3 { score += 2 }
        if hasMetrics { score += 2 }
        if hasSections >= 2 { score += 1 }
        return min(score, 10)
    }

    private func scoreExperience(resume: String, job: String, matchedKeywords: [String]) -> Int {
        let resumeYears = resume.range(of: #"\d+\+?\s*(years|yrs)"#, options: [.regularExpression, .caseInsensitive]) != nil
        let jobYears = job.range(of: #"\d+\+?\s*(years|yrs)"#, options: [.regularExpression, .caseInsensitive]) != nil
        var score = min(10, 4 + matchedKeywords.count / 3)
        if resumeYears == jobYears || resumeYears { score += 1 }
        return min(score, 10)
    }

    private func makeStrengths(matched: [String], categories: [ScoreCategory]) -> [String] {
        var strengths: [String] = []
        if !matched.isEmpty {
            strengths.append("Your resume already mirrors important role language like \(matched.prefix(5).joined(separator: ", ")).")
        }
        if categories.first(where: { $0.name == "Resume Clarity" })?.score ?? 0 >= 8 {
            strengths.append("The resume is structured clearly enough for quick screening.")
        }
        if categories.first(where: { $0.name == "Seniority Fit" })?.score ?? 0 >= 8 {
            strengths.append("The seniority signals are aligned with the posting.")
        }
        return strengths.isEmpty ? ["There is enough overlap to create a targeted version of this resume."] : strengths
    }

    private func makeGaps(missing: [String], categories: [ScoreCategory]) -> [String] {
        var gaps: [String] = []
        if !missing.isEmpty {
            gaps.append("The posting emphasizes \(missing.prefix(6).joined(separator: ", ")), which are not obvious in the resume text.")
        }
        if categories.first(where: { $0.name == "Keyword Alignment" })?.score ?? 0 < 6 {
            gaps.append("Keyword alignment is low, so the resume may underperform with automated screening.")
        }
        if categories.first(where: { $0.name == "Required Skills" })?.score ?? 0 < 6 {
            gaps.append("Several required skill signals should be made explicit if you have that experience.")
        }
        return gaps
    }
}

import Foundation

struct ResumeScoringService {
    private struct SkillSignal {
        let keyword: String
        let aliases: [String]
        let weight: Int

        init(_ keyword: String, aliases: [String] = [], weight: Int = 6) {
            self.keyword = keyword
            self.aliases = aliases
            self.weight = weight
        }

        var searchTerms: [String] {
            [keyword] + aliases
        }
    }

    private let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "you", "your", "are", "will", "have", "has", "our", "their", "they", "job", "role", "work", "team", "experience", "candidate", "preferred", "required", "requirements", "responsibilities", "ability", "using", "into", "about", "within", "across", "strong", "excellent", "including", "such", "etc", "can", "all", "any", "who", "what", "when", "where", "how", "why", "but", "not", "was", "were", "been", "being", "than", "then", "them", "his", "her", "its", "per", "via", "company", "employer", "business", "customer", "customers", "client", "clients", "applicant", "applicants", "apply", "applying", "opportunity", "equal", "employment", "benefit", "benefits", "salary", "compensation", "office", "remote", "hybrid", "onsite", "location", "locations", "inc", "llc", "ltd", "corp", "corporation", "limited", "global", "north", "south", "east", "west", "canada", "united", "states", "toronto", "ontario"
    ]

    private let technicalSkillHints: Set<String> = [
        "swift", "swiftui", "ios", "xcode", "uikit", "combine", "async", "api", "rest", "graphql", "aws", "azure", "gcp", "docker", "kubernetes", "ci", "cd", "github", "actions", "jenkins", "sql", "postgres", "postgresql", "mysql", "mongodb", "firebase", "coredata", "python", "java", "javascript", "typescript", "react", "node", "cloud", "security", "testing", "analytics", "observability", "datadog", "splunk", "figma", "agile", "scrum", "leadership", "architecture", "mvvm", "ocr", "vision", "pdf", "excel", "tableau", "powerbi", "snowflake", "spark", "kafka", "redis", "terraform", "salesforce", "jira"
    ]

    private let skillSignals: [SkillSignal] = [
        SkillSignal("swift"), SkillSignal("swiftui"), SkillSignal("ios", aliases: ["iphone", "ipad", "mobile"]), SkillSignal("xcode"), SkillSignal("uikit"), SkillSignal("combine"),
        SkillSignal("async/await", aliases: ["async await", "concurrency"], weight: 5), SkillSignal("core data", aliases: ["coredata"]), SkillSignal("ocr", aliases: ["optical character recognition"]), SkillSignal("vision", aliases: ["vision framework"]),
        SkillSignal("api", aliases: ["apis", "api integration"]), SkillSignal("rest", aliases: ["restful"]), SkillSignal("graphql"), SkillSignal("json"), SkillSignal("microservices", aliases: ["micro services"]),
        SkillSignal("aws", aliases: ["amazon web services"]), SkillSignal("azure", aliases: ["microsoft azure"]), SkillSignal("gcp", aliases: ["google cloud", "google cloud platform"]), SkillSignal("cloud"),
        SkillSignal("docker"), SkillSignal("kubernetes", aliases: ["k8s"]), SkillSignal("terraform"), SkillSignal("ci/cd", aliases: ["ci cd", "continuous integration", "continuous delivery", "continuous deployment"]),
        SkillSignal("github actions", aliases: ["github action"]), SkillSignal("jenkins"), SkillSignal("git"), SkillSignal("jira"),
        SkillSignal("sql"), SkillSignal("postgresql", aliases: ["postgres"]), SkillSignal("mysql"), SkillSignal("mongodb", aliases: ["mongo"]), SkillSignal("redis"), SkillSignal("firebase"),
        SkillSignal("python"), SkillSignal("java"), SkillSignal("javascript", aliases: ["js"]), SkillSignal("typescript", aliases: ["ts"]), SkillSignal("react", aliases: ["reactjs", "react.js"]), SkillSignal("node.js", aliases: ["nodejs", "node"]),
        SkillSignal("html"), SkillSignal("css"), SkillSignal("spark"), SkillSignal("kafka"), SkillSignal("snowflake"),
        SkillSignal("testing", aliases: ["unit testing", "test automation", "automated tests", "qa"], weight: 5), SkillSignal("security"), SkillSignal("analytics"), SkillSignal("observability"), SkillSignal("datadog"), SkillSignal("splunk"),
        SkillSignal("figma"), SkillSignal("agile"), SkillSignal("scrum"), SkillSignal("architecture"), SkillSignal("mvvm"), SkillSignal("clean architecture", aliases: ["clean-architecture"]),
        SkillSignal("excel"), SkillSignal("tableau"), SkillSignal("power bi", aliases: ["powerbi"]), SkillSignal("salesforce"), SkillSignal("project management", aliases: ["program management"], weight: 4), SkillSignal("stakeholder management", aliases: ["stakeholders"], weight: 4), SkillSignal("leadership", weight: 4)
    ]

    func score(resume: ResumeDocument, job: JobPosting) -> ResumeMatchDraft {
        let resumeTerms = weightedTerms(from: resume.text, allowGeneralTerms: true)
        let jobTerms = weightedTerms(from: job.text, allowGeneralTerms: false)
        let jobKeywords = extractJobKeywords(from: job.text, weightedTerms: jobTerms)
        let resumeKeywordSet = Set(extractResumeKeywords(from: resume.text, weightedTerms: resumeTerms))

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

    private func weightedTerms(from text: String, allowGeneralTerms: Bool) -> [String: Int] {
        let words = text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9+#. ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }
            .filter { allowGeneralTerms || technicalSkillHints.contains($0) }

        return words.reduce(into: [:]) { counts, word in
            counts[word, default: 0] += technicalSkillHints.contains(word) ? 3 : 1
        }
    }

    private func extractJobKeywords(from text: String, weightedTerms: [String: Int]) -> [String] {
        var scores = skillScores(in: text)
        for (term, count) in weightedTerms where technicalSkillHints.contains(term) {
            scores[term, default: 0] += count
        }
        return rankedKeywords(from: scores, limit: 24)
    }

    private func extractResumeKeywords(from text: String, weightedTerms: [String: Int]) -> [String] {
        var scores = skillScores(in: text)
        for (term, count) in weightedTerms {
            scores[term, default: 0] += count
        }
        return rankedKeywords(from: scores, limit: 40)
    }

    private func skillScores(in text: String) -> [String: Int] {
        var scores: [String: Int] = [:]
        for signal in skillSignals {
            let hits = signal.searchTerms.reduce(0) { total, term in
                total + occurrenceCount(of: term, in: text)
            }
            if hits > 0 {
                scores[signal.keyword, default: 0] += signal.weight + hits
            }
        }
        return scores
    }

    private func rankedKeywords(from scores: [String: Int], limit: Int) -> [String] {
        scores.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        .prefix(limit)
        .map(\.key)
    }

    private func occurrenceCount(of term: String, in text: String) -> Int {
        let escaped = NSRegularExpression.escapedPattern(for: term.lowercased())
            .replacingOccurrences(of: "\\ ", with: #"\s+"#)
        let pattern = #"(?<![a-z0-9+#.])"# + escaped + #"(?![a-z0-9+#.])"#
        let range = NSRange(text.lowercased().startIndex..., in: text.lowercased())
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
            .numberOfMatches(in: text.lowercased(), range: range) ?? 0
    }

    private func normalizedScore(matched: Int, total: Int, max: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(max, Int(round(Double(matched) / Double(total) * Double(max))))
    }

    private func scoreRequiredSignals(resumeTerms: [String: Int], jobTerms: [String: Int]) -> Int {
        let requiredSignals = Set(jobTerms.keys).intersection(technicalSkillHints)
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

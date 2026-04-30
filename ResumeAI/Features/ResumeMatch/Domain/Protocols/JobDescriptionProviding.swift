import Foundation

protocol JobDescriptionProviding {
    func resolveJob(from input: JobInput) async throws -> JobPosting
}

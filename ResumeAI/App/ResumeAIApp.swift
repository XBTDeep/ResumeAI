import SwiftUI

@main
struct ResumeAIApp: App {
    var body: some Scene {
        WindowGroup {
            ResumeMatchView(viewModel: ResumeMatchViewModel())
        }
    }
}

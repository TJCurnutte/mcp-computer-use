import Foundation

/// Reads and writes the first-run onboarding flag at
/// `~/.mcp-computer-use/onboarding-complete`.
final class FirstRunChecker {
    static let shared = FirstRunChecker()

    private init() {}

    private var flagURL: URL {
        Paths.mcpDirectory.appendingPathComponent("onboarding-complete", isDirectory: false)
    }

    var isFirstRun: Bool {
        !FileManager.default.fileExists(atPath: flagURL.path)
    }

    func markOnboardingComplete() {
        ensureDirectory()
        FileManager.default.createFile(atPath: flagURL.path, contents: Data(), attributes: nil)
    }

    func resetOnboarding() {
        try? FileManager.default.removeItem(at: flagURL)
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: Paths.mcpDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}

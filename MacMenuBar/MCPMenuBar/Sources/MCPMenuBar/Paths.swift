import Foundation

struct Paths {
    static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var mcpDirectory: URL {
        home.appendingPathComponent(".mcp-computer-use", isDirectory: true)
    }

    static var logDirectory: URL {
        mcpDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    static var logFile: URL {
        logDirectory.appendingPathComponent("mcp-menubar.log")
    }

    static var portFile: URL {
        mcpDirectory.appendingPathComponent("mcp.port")
    }

    /// The directory containing the mcp-computer-use Python package.
    /// First checks MCP_SERVER_ROOT, then walks up from the app bundle looking
    /// for the repo, and finally falls back to ~/CascadeProjects/mcp-computer-use.
    static var repoRoot: URL {
        if let envPath = ProcessInfo.processInfo.environment["MCP_SERVER_ROOT"],
           !envPath.isEmpty,
           FileManager.default.fileExists(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }

        var candidate = Bundle.main.bundleURL
        for _ in 0..<8 {
            candidate = candidate.deletingLastPathComponent()
            let marker = candidate.appendingPathComponent("mcp_computer_use")
            if FileManager.default.fileExists(atPath: marker.path) {
                return candidate
            }
        }

        return home.appendingPathComponent("CascadeProjects/mcp-computer-use", isDirectory: true)
    }
}

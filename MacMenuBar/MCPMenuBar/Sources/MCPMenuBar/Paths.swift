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
}

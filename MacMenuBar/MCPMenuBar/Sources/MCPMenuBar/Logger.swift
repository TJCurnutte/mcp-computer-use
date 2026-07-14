import Foundation

final class Logger {
    static let shared = Logger()

    private let queue = DispatchQueue(label: "com.example.MCPMenuBar.logger")
    private let maxSize: UInt64 = 1_048_576 // 1 MiB

    private var logFileURL: URL {
        Paths.logFile
    }

    private init() {
        try? FileManager.default.createDirectory(at: Paths.logDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        queue.async { [weak self] in
            guard let self = self else { return }
            self.writeLine(line)
        }
    }

    private func writeLine(_ line: String) {
        let data = line.data(using: .utf8) ?? Data()
        let fm = FileManager.default

        if fm.fileExists(atPath: logFileURL.path) {
            if let attrs = try? fm.attributesOfItem(atPath: logFileURL.path),
               let size = attrs[.size] as? UInt64,
               size > maxSize {
                // Truncate by replacing with empty file.
                try? Data().write(to: logFileURL, options: .atomic)
            }

            if let handle = FileHandle(forWritingAtPath: logFileURL.path) {
                handle.seekToEndOfFile()
                try? handle.write(contentsOf: data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }
}

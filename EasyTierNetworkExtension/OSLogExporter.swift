import Foundation
import OSLog

enum OSLogExporter {
    private static var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    enum ExportError: Error {
        case containerUnavailable
        case emptyLogs
    }

    static func exportToAppGroup(appGroupID: String) throws -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            throw ExportError.containerUnavailable
        }
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        // Start with recent diagnostics so the size cap does not preserve only old history.
        let entries = try store.getEntries(with: .reverse)
        let formatter = dateFormatter
        let lines = entries.lazy.compactMap { entry -> String? in
            autoreleasepool {
                if let log = entry as? OSLogEntryLog { return format(log, formatter: formatter) }
                if let signpost = entry as? OSLogEntrySignpost { return format(signpost, formatter: formatter) }
                return nil
            }
        }
        let url = containerURL.appendingPathComponent("EasyTier-NE-oslog-\(UUID().uuidString).log")
        try writeLines(lines, to: url)
        return url
    }

    // Never accumulate the process's entire log history in the 150 MB VPN extension.
    // Bound disk output too, while keeping enumeration lazy and per-entry temporaries short lived.
    static func writeLines<S: Sequence>(_ lines: S, to url: URL, maxBytes: Int = 8 * 1024 * 1024) throws where S.Element == String {
        let marker = Data("[Export truncated: size limit reached]\n".utf8)
        guard maxBytes >= marker.count else { throw ExportError.emptyLogs }
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let file = try FileHandle(forWritingTo: url)
        var success = false
        defer { try? file.close(); if !success { try? FileManager.default.removeItem(at: url) } }
        var written = 0
        for line in lines {
            let data = Data((line + "\n").utf8)
            if data.count > maxBytes - marker.count - written {
                try file.write(contentsOf: marker); written += marker.count; break
            }
            try file.write(contentsOf: data); written += data.count
        }
        guard written > 0 else { throw ExportError.emptyLogs }
        success = true
    }

    private static func format(_ log: OSLogEntryLog, formatter: ISO8601DateFormatter) -> String {
        let timestamp = formatter.string(from: log.date)
        let level = formatLevel(log.level)
        let subsystem = log.subsystem
        let category = log.category
        return "[\(timestamp)] [\(level)] [\(subsystem)] [\(category)] \(log.composedMessage)"
    }

    private static func format(_ signpost: OSLogEntrySignpost, formatter: ISO8601DateFormatter) -> String {
        let timestamp = formatter.string(from: signpost.date)
        let type = String(describing: signpost.signpostType).uppercased()
        let subsystem = signpost.subsystem
        let category = signpost.category
        let name = signpost.signpostName
        return "[\(timestamp)] [SIGNPOST \(type)] [\(subsystem)] [\(category)] \(name)"
    }

    private static func formatLevel(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .notice:
            return "NOTICE"
        case .error:
            return "ERROR"
        case .fault:
            return "FAULT"
        default:
            return "UNKNOWN"
        }
    }
}

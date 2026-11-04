import Foundation
@main struct MemoryExportTests {
 static func main() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try OSLogExporter.writeLines(["first", "中文日志"], to: url)
    let small = try String(contentsOf: url, encoding: .utf8)
    precondition(small == "first\n中文日志\n")
    var visited = 0
    let lines = (0..<1_000_000).lazy.map { i -> String in visited += 1; return String(repeating: "x", count: 4096) }
    try OSLogExporter.writeLines(lines, to: url, maxBytes: 65536)
    let output = try Data(contentsOf: url)
    precondition(output.count <= 65536 && visited < 20)
    precondition(String(decoding: output, as: UTF8.self).hasSuffix("[Export truncated: size limit reached]\n"))
    do { try OSLogExporter.writeLines([String](), to: url); fatalError("empty export accepted") } catch OSLogExporter.ExportError.emptyLogs {}
    precondition(!FileManager.default.fileExists(atPath: url.path))
    print("PASS: UTF-8 streaming, bounded lazy enumeration, capped output, truncation marker, empty-file cleanup")
 }
}

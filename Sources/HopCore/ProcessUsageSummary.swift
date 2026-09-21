import Foundation

public struct ProcessUsageEntry: Equatable, Sendable {
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryBytes: Int64

    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: Int64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}

public struct ProcessUsageSummary: Equatable, Sendable {
    public let topCPU: ProcessUsageEntry?
    public let topMemory: ProcessUsageEntry?

    public init(topCPU: ProcessUsageEntry?, topMemory: ProcessUsageEntry?) {
        self.topCPU = topCPU
        self.topMemory = topMemory
    }

    /// Parses:
    ///
    ///     ps -axo pid=,pcpu=,rss=,comm=
    ///
    /// Only aggregate process identity / CPU / resident memory is retained.
    /// Arguments, document titles and window contents never enter the model.
    public static func parsePS(_ output: String, excludingPID: Int32? = nil) -> ProcessUsageSummary {
        var entries: [ProcessUsageEntry] = []

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // Split the first three whitespace-delimited columns and preserve the
            // remainder verbatim because executable paths can contain spaces.
            var parts: [Substring] = []
            var start = line.startIndex
            var cursor = start

            func skipSpaces() {
                while cursor < line.endIndex, line[cursor].isWhitespace {
                    cursor = line.index(after: cursor)
                }
            }

            skipSpaces()
            for _ in 0..<3 {
                let fieldStart = cursor
                while cursor < line.endIndex, !line[cursor].isWhitespace {
                    cursor = line.index(after: cursor)
                }
                guard fieldStart < cursor else { break }
                parts.append(line[fieldStart..<cursor])
                skipSpaces()
            }

            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = Int64(parts[2]),
                  pid != excludingPID,
                  cursor < line.endIndex
            else { continue }

            let command = String(line[cursor...]).trimmingCharacters(in: .whitespaces)
            guard !command.isEmpty else { continue }

            let displayName = URL(fileURLWithPath: command).lastPathComponent
            let name = displayName.isEmpty ? command : displayName
            entries.append(ProcessUsageEntry(
                pid: pid,
                name: name,
                cpuPercent: max(0, cpu),
                memoryBytes: max(0, rssKB) * 1024
            ))
        }

        return ProcessUsageSummary(
            topCPU: entries.max {
                if $0.cpuPercent != $1.cpuPercent { return $0.cpuPercent < $1.cpuPercent }
                return $0.pid > $1.pid
            },
            topMemory: entries.max {
                if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes < $1.memoryBytes }
                return $0.pid > $1.pid
            }
        )
    }
}

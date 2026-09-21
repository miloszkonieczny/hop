import Foundation
import HopCore

/// Lightweight process summary for the Mac dashboard.
///
/// Runs only while that dashboard is visible. It reads the standard `ps`
/// aggregate columns (pid, CPU %, resident memory, executable) and persists
/// nothing.
@MainActor
final class MacProcessSummaryController: ObservableObject {
    @Published private(set) var summary = ProcessUsageSummary(topCPU: nil, topMemory: nil)

    private var timer: Timer?
    private var inFlight = false

    func start() {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !inFlight, !Snapshot.active else { return }
        inFlight = true
        let ownPID = Int32(ProcessInfo.processInfo.processIdentifier)

        Task.detached(priority: .utility) { [weak self] in
            let output = Self.readPS()
            let parsed = ProcessUsageSummary.parsePS(output, excludingPID: ownPID)
            await MainActor.run {
                guard let self else { return }
                self.summary = parsed
                self.inFlight = false
            }
        }
    }

    private nonisolated static func readPS() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,rss=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

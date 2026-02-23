import Foundation

enum AIPrompt {
    static func generate() {
        let issues = Detector.scan()
        let prompt = buildPrompt(issues: issues)

        // Copy to clipboard via pbcopy
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        process.standardInput = pipe
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            pipe.fileHandleForWriting.write(Data(prompt.utf8))
            pipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()
            print("Prompt copied to clipboard.\n")
        } catch {
            print("Warning: Could not copy to clipboard - \(error)\n")
        }

        print(prompt)
    }

    // MARK: - Private

    private static func buildPrompt(issues: [Issue]) -> String {
        var lines: [String] = []

        lines.append("I'm having the following macOS process issues detected by ghostkill:")
        lines.append("")

        let categories: [(tag: String, label: String)] = [
            ("zombie",           "Zombie Terminal Sessions"),
            ("zombie-state",     "Zombie Processes (Z State)"),
            ("duplicate",        "Duplicate Processes"),
            ("resource",         "High CPU/Memory Usage"),
            ("orphan",           "Orphan Processes"),
            ("port",             "Port Occupancy"),
            ("terminal-session", "Terminal Sessions"),
            ("version-mismatch", "Version Mismatch"),
            ("launchctl",        "LaunchCtl Agents"),
            ("launch-agent",     "LaunchAgents"),
            ("login-item",       "Login Items"),
            ("timemachine",      "Time Machine"),
            ("network",          "Network Status"),
            ("disk",             "Disk Usage"),
        ]

        var printed = Set<String>()

        for cat in categories {
            let group = issues.filter { $0.tag == cat.tag }
            guard !group.isEmpty else { continue }
            lines.append("[\(cat.label)]")
            for issue in group {
                let pidStr = issue.pids.isEmpty ? "" : " (PIDs: \(issue.pids.map(String.init).joined(separator: ", ")))"
                lines.append("- \(issue.description)\(pidStr)")
            }
            lines.append("")
            printed.insert(cat.tag)
        }

        let rest = issues.filter { !printed.contains($0.tag) }
        if !rest.isEmpty {
            lines.append("[Other]")
            for issue in rest {
                lines.append("- \(issue.description)")
            }
            lines.append("")
        }

        if issues.isEmpty {
            lines.append("(No issues detected at this time.)")
            lines.append("")
        }

        lines.append("Please help me:")
        lines.append("1. Understand what's causing these issues")
        lines.append("2. Fix them safely")
        lines.append("3. Prevent them in the future")
        lines.append("")

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        lines.append("System: macOS \(osVersion), ghostkill v\(ghostkillVersion)")

        return lines.joined(separator: "\n")
    }
}

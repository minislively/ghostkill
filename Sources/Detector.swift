import Foundation

struct Issue {
    let description: String
    let pids: [Int32]
    let tag: String
}

enum Detector {
    // Zombie terminal patterns left by IDEs
    static let zombiePatterns: [(pattern: String, label: String)] = [
        ("kiro-cli-term",     "Kiro CLI"),
        ("cursor-cli-term",   "Cursor"),
        ("vscode-cli-term",   "VS Code"),
        ("windsurf-cli-term", "Windsurf"),
    ]

    // Duplicate process detection targets
    static let duplicateTargets: [(name: String, threshold: Int)] = [
        ("claude", 5),
        ("node",   10),
        ("bun",    5),
    ]

    // Development port list
    static let devPorts: [Int] = [3000, 3001, 4000, 5000, 5173, 8000, 8080, 8888, 9000]

    // System process exclusions for orphan detection
    static let systemProcessExclusions: Set<String> = [
        "launchd", "kernel_task", "UserEventAgent", "loginwindow", "WindowServer",
        "mds", "mds_stores", "mdworker", "distnoted", "cfprefsd", "lsd",
        "configd", "opendirectoryd", "syspolicyd", "trustd", "SecurityAgent",
        "coreaudiod", "sharingd", "syslogd", "notifyd", "logd", "powerd",
        "airportd", "bluetoothd", "locationd", "nsurlsessiond", "nsurlstoraged",
        "rapportd", "rtcreportingd", "spindump", "osanalyticshelper",
        "thermald", "secd", "akd", "coreduetd",
    ]

    static func scan() -> [Issue] {
        var issues: [Issue] = []

        // 1. Zombie terminal session detection
        for z in zombiePatterns {
            let pids = findPIDs(pattern: z.pattern)
            if !pids.isEmpty {
                issues.append(Issue(
                    description: "\(z.label) zombie terminal session(s) found: \(pids.count)",
                    pids: pids,
                    tag: "zombie"
                ))
            }
        }

        // 2. Duplicate process detection
        for d in duplicateTargets {
            let pids = findPIDs(pattern: d.name)
            if pids.count >= d.threshold {
                issues.append(Issue(
                    description: "\(d.name) has \(pids.count) instances running (threshold: \(d.threshold))",
                    pids: pids,
                    tag: "duplicate"
                ))
            }
        }

        // 3. launchctl agent detection
        let launchctlIssues = scanLaunchctl()
        issues.append(contentsOf: launchctlIssues)

        // 4+5+8+spotlight: run ps aux once and share
        let psLines = psAuxLines()

        // 4. High CPU/memory process detection
        let resourceIssues = scanHighResourceProcesses(psLines: psLines)
        issues.append(contentsOf: resourceIssues)

        // 5. Zombie processes (Z state) detection
        let zombieStateIssues = scanZombieStateProcesses(psLines: psLines)
        issues.append(contentsOf: zombieStateIssues)

        // 6. Orphan process detection
        let orphanIssues = scanOrphanProcesses()
        issues.append(contentsOf: orphanIssues)

        // 7. Port occupancy tracking
        let portIssues = scanPortOccupancy()
        issues.append(contentsOf: portIssues)

        // 8. Running commands per terminal session
        let terminalIssues = scanTerminalSessions(psLines: psLines)
        issues.append(contentsOf: terminalIssues)

        // 9. nvm/rbenv/pyenv version conflict detection
        let versionIssues = scanVersionMismatches()
        issues.append(contentsOf: versionIssues)

        // 10. macOS system-level detection
        let loginItemIssues = scanLoginItems()
        issues.append(contentsOf: loginItemIssues)

        let spotlightIssues = scanSpotlightOverload(psLines: psLines)
        issues.append(contentsOf: spotlightIssues)

        let launchAgentIssues = scanLaunchAgentsDirectory()
        issues.append(contentsOf: launchAgentIssues)

        // 11. Time Machine backup in progress detection
        let timeMachineIssues = scanTimeMachine()
        issues.append(contentsOf: timeMachineIssues)

        // 12. Network status detection
        let networkIssues = scanNetwork()
        issues.append(contentsOf: networkIssues)

        // 13. Disk usage warning
        let diskIssues = scanDisk()
        issues.append(contentsOf: diskIssues)

        return issues
    }

    // Known unnecessary launchctl agent prefixes
    static let launchctlPrefixes: [(prefix: String, label: String)] = [
        ("com.kiro",           "Kiro"),
        ("com.cursor",         "Cursor"),
        ("com.adobe",          "Adobe"),
        ("com.google.keystone", "Google Keystone Update"),
    ]

    static func scanLaunchctl() -> [Issue] {
        let output = shell("/bin/launchctl", ["list"])
        guard !output.isEmpty else { return [] }

        var issues: [Issue] = []
        for entry in launchctlPrefixes {
            let matched = output.split(separator: "\n").filter { $0.contains(entry.prefix) }
            if !matched.isEmpty {
                issues.append(Issue(
                    description: "\(entry.label) launchctl agent(s) detected: \(matched.count) (\(entry.prefix)*)",
                    pids: [],
                    tag: "launchctl"
                ))
            }
        }
        return issues
    }

    // MARK: - High CPU/Memory process detection

    static func psAuxLines() -> [Substring] {
        let output = shell("/bin/ps", ["aux"])
        return Array(output.split(separator: "\n").dropFirst())
    }

    static func scanHighResourceProcesses(psLines: [Substring]) -> [Issue] {
        // ps aux: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
        var issues: [Issue] = []

        for line in psLines {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 11 else { continue }

            let pidStr  = String(cols[1])
            let cpuStr  = String(cols[2])
            let rssStr  = String(cols[5])  // RSS in KB
            let command = String(cols[10])

            guard let pid = Int32(pidStr),
                  let cpu = Double(cpuStr),
                  let rssKB = Int(rssStr) else { continue }

            let memMB = Double(rssKB) / 1024.0

            if cpu > 80.0 {
                issues.append(Issue(
                    description: "\(command) using CPU \(String(format: "%.1f", cpu))%",
                    pids: [pid],
                    tag: "resource"
                ))
            } else if memMB > 500.0 {
                issues.append(Issue(
                    description: "\(command) using memory \(String(format: "%.0f", memMB))MB",
                    pids: [pid],
                    tag: "resource"
                ))
            }
        }
        return issues
    }

    // MARK: - Zombie processes (Z state) detection

    static func scanZombieStateProcesses(psLines: [Substring]) -> [Issue] {
        var zombiePIDs: [Int32] = []

        for line in psLines {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 8 else { continue }
            let stat   = String(cols[7])
            let pidStr = String(cols[1])
            if stat.hasPrefix("Z"), let pid = Int32(pidStr) {
                zombiePIDs.append(pid)
            }
        }

        guard !zombiePIDs.isEmpty else { return [] }
        return [Issue(
            description: "\(zombiePIDs.count) zombie process(es) detected (Z state)",
            pids: zombiePIDs,
            tag: "zombie-state"
        )]
    }

    // MARK: - Orphan process detection (PPID == 1, regular user processes)

    static func scanOrphanProcesses() -> [Issue] {
        // ps -eo pid,ppid,user,comm
        let output = shell("/bin/ps", ["-eo", "pid,ppid,user,comm"])
        var orphanPIDs: [Int32] = []

        let currentUser = ProcessInfo.processInfo.environment["USER"] ?? ""

        for line in output.split(separator: "\n").dropFirst() {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 4 else { continue }
            let pidStr  = String(cols[0])
            let ppidStr = String(cols[1])
            let user    = String(cols[2])
            let comm    = String(cols[3])

            guard let pid  = Int32(pidStr),
                  let ppid = Int32(ppidStr),
                  ppid == 1 else { continue }

            // Exclude system processes
            guard !systemProcessExclusions.contains(comm) else { continue }
            // Exclude root and system accounts
            guard user != "root" && user != "_" && !user.hasPrefix("_") else { continue }
            // Include only current user processes
            guard user == currentUser else { continue }

            orphanPIDs.append(pid)
        }

        guard !orphanPIDs.isEmpty else { return [] }
        return [Issue(
            description: "\(orphanPIDs.count) orphan process(es) detected (PPID=1, regular user)",
            pids: orphanPIDs,
            tag: "orphan"
        )]
    }

    // MARK: - Port occupancy tracking

    static func scanPortOccupancy() -> [Issue] {
        var issues: [Issue] = []

        for port in devPorts {
            let output = shell("/usr/sbin/lsof", ["-ti", ":\(port)"])
            let pids = output.split(separator: "\n")
                .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            guard !pids.isEmpty else { continue }

            // Look up process name
            let firstPID = pids[0]
            let commOut = shell("/bin/ps", ["-p", "\(firstPID)", "-o", "comm="])
            let procName = commOut.trimmingCharacters(in: .whitespacesAndNewlines)

            issues.append(Issue(
                description: "Port \(port) occupied by: \(procName) (PID \(firstPID))",
                pids: pids,
                tag: "port"
            ))
        }
        return issues
    }

    // MARK: - Running commands per terminal session

    static func scanTerminalSessions(psLines: [Substring]) -> [Issue] {
        // tty column (cols[6]) in s000~s999 form
        var sessionMap: [String: [(pid: Int32, comm: String)]] = [:]

        for line in psLines {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 11 else { continue }
            let pidStr  = String(cols[1])
            let tty     = String(cols[6])
            let command = cols[10...].joined(separator: " ")

            guard tty.hasPrefix("s"), tty.count == 4,
                  tty.dropFirst().allSatisfy({ $0.isNumber }),
                  let pid = Int32(pidStr) else { continue }

            // Exclude zsh/bash/sh
            let baseCmd = String(command.split(separator: "/").last ?? Substring(command))
                .split(separator: " ").first.map(String.init) ?? command
            let shellNames: Set<String> = ["zsh", "bash", "sh", "fish", "tcsh", "csh", "-zsh", "-bash"]
            guard !shellNames.contains(baseCmd) else { continue }

            sessionMap[tty, default: []].append((pid: pid, comm: baseCmd))
        }

        guard !sessionMap.isEmpty else { return [] }

        var issues: [Issue] = []
        for (tty, procs) in sessionMap.sorted(by: { $0.key < $1.key }) {
            let desc = procs.map { "\($0.comm)(PID \($0.pid))" }.joined(separator: ", ")
            issues.append(Issue(
                description: "Terminal \(tty): \(desc)",
                pids: procs.map { $0.pid },
                tag: "terminal-session"
            ))
        }
        return issues
    }

    // MARK: - nvm/rbenv/pyenv version mismatch detection

    static func scanVersionMismatches() -> [Issue] {
        var issues: [Issue] = []
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""

        // Node.js version check
        let nvmrcPath = "\(home)/.nvmrc"
        let nodeVersionPath = "\(home)/.node-version"
        var expectedNode: String? = nil

        if let content = try? String(contentsOfFile: nvmrcPath, encoding: .utf8) {
            expectedNode = content.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let content = try? String(contentsOfFile: nodeVersionPath, encoding: .utf8) {
            expectedNode = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let expected = expectedNode {
            let actual = shell("/usr/bin/env", ["node", "--version"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !actual.isEmpty && !actual.hasPrefix(expected.hasPrefix("v") ? expected : "v\(expected)") {
                issues.append(Issue(
                    description: "Node.js version mismatch - current: \(actual), expected: \(expected)",
                    pids: [],
                    tag: "version-mismatch"
                ))
            }
        }

        // Ruby version check
        let rubyVersionPath = "\(home)/.ruby-version"
        if let expected = try? String(contentsOfFile: rubyVersionPath, encoding: .utf8) {
            let expectedTrimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)
            let actual = shell("/usr/bin/env", ["ruby", "--version"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !actual.isEmpty && !actual.contains(expectedTrimmed) {
                issues.append(Issue(
                    description: "Ruby version mismatch - current: \(actual), expected: \(expectedTrimmed)",
                    pids: [],
                    tag: "version-mismatch"
                ))
            }
        }

        // Python version check
        let pythonVersionPath = "\(home)/.python-version"
        if let expected = try? String(contentsOfFile: pythonVersionPath, encoding: .utf8) {
            let expectedTrimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)
            let actual = shell("/usr/bin/env", ["python3", "--version"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !actual.isEmpty && !actual.contains(expectedTrimmed) {
                issues.append(Issue(
                    description: "Python version mismatch - current: \(actual), expected: \(expectedTrimmed)",
                    pids: [],
                    tag: "version-mismatch"
                ))
            }
        }

        return issues
    }

    // MARK: - macOS Login Items scan

    static func scanLoginItems() -> [Issue] {
        print("  [info] Querying Login Items - system may request permission (osascript)")
        let output = shell("/usr/bin/osascript", [
            "-e", "tell application \"System Events\" to get the name of every login item"
        ])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let items = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return [Issue(
            description: "\(items.count) Login Item(s) registered: \(items.joined(separator: ", "))",
            pids: [],
            tag: "login-item"
        )]
    }

    // MARK: - Spotlight overload detection

    static func scanSpotlightOverload(psLines: [Substring]) -> [Issue] {
        var issues: [Issue] = []

        for line in psLines {
            guard line.contains("mds_stores") else { continue }
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 3,
                  let pid = Int32(String(cols[1])),
                  let cpu = Double(String(cols[2])),
                  cpu > 50.0 else { continue }

            issues.append(Issue(
                description: "Spotlight(mds_stores) CPU overload \(String(format: "%.1f", cpu))%",
                pids: [pid],
                tag: "resource"
            ))
        }
        return issues
    }

    // MARK: - LaunchAgents directory scan

    static func scanLaunchAgentsDirectory() -> [Issue] {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let launchAgentsPath = "\(home)/Library/LaunchAgents"

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: launchAgentsPath) else { return [] }

        let plists = files.filter { $0.hasSuffix(".plist") }
        guard !plists.isEmpty else { return [] }

        return [Issue(
            description: "~/Library/LaunchAgents has \(plists.count) plist(s) registered",
            pids: [],
            tag: "launch-agent"
        )]
    }

    // MARK: - Network status detection

    static func scanNetwork() -> [Issue] {
        // networkQuality -s -c (macOS 12+) attempt
        let nqOutput = shell("/usr/bin/networkQuality", ["-s", "-c"])
        if !nqOutput.isEmpty {
            // JSON parsing: responsiveness or latency field
            // If not failed, consider network healthy; only check latency
            // networkQuality JSON: {"responsiveness":...,"dlThroughput":...,"ulThroughput":...}
            // Latency measured via ping fallback
        }

        // Measure latency with ping -c 3 8.8.8.8
        let pingOutput = shell("/sbin/ping", ["-c", "3", "-t", "5", "8.8.8.8"])
        if pingOutput.isEmpty || pingOutput.contains("Request timeout") || pingOutput.contains("100.0% packet loss") {
            return [Issue(
                description: "No network connection or unstable",
                pids: [],
                tag: "network"
            )]
        }

        // Parse avg rtt: "round-trip min/avg/max/stddev = 1.234/5.678/9.012/1.000 ms"
        for line in pingOutput.split(separator: "\n") {
            let l = String(line)
            if l.contains("round-trip") || l.contains("rtt") {
                // min/avg/max/stddev
                let parts = l.split(separator: "=")
                if parts.count >= 2 {
                    let stats = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    let nums = stats.split(separator: "/")
                    if nums.count >= 2, let avg = Double(String(nums[1]).trimmingCharacters(in: .whitespaces)) {
                        if avg >= 200.0 {
                            return [Issue(
                                description: "High network latency (\(String(format: "%.0f", avg))ms)",
                                pids: [],
                                tag: "network"
                            )]
                        }
                    }
                }
            }
        }

        return []
    }

    // MARK: - Disk usage warning

    static func scanDisk() -> [Issue] {
        let output = shell("/bin/df", ["-h", "/"])
        // df -h output: Filesystem  Size  Used  Avail  Capacity  iused  ifree  %iused  Mounted
        // macOS format: Filesystem   Size   Used  Avail Capacity iused      ifree %iused  Mounted on
        for line in output.split(separator: "\n").dropFirst() {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            // macOS df -h: Filesystem Size Used Avail Capacity(%) iused ifree %iused Mounted
            // capacity is 5th column (index 4) or "Use%" column
            guard cols.count >= 5 else { continue }

            // Find capacity column: "XX%" form
            var capacityStr: String? = nil
            var availStr: String? = nil
            for (i, col) in cols.enumerated() {
                let s = String(col)
                if s.hasSuffix("%"), let pct = Int(s.dropLast()) {
                    _ = pct
                    capacityStr = s
                    // avail is the column immediately before capacity
                    if i > 0 { availStr = String(cols[i - 1]) }
                    break
                }
            }

            guard let capStr = capacityStr,
                  let pct = Int(capStr.dropLast()),
                  pct >= 85 else { continue }

            let avail = availStr ?? "?"
            return [Issue(
                description: "Low disk space - \(pct)% used (available: \(avail))",
                pids: [],
                tag: "disk"
            )]
        }
        return []
    }

    // MARK: - Specific app detailed report

    static func scanApp(name: String) -> String {
        var lines: [String] = []
        lines.append("=== \(name) Process Detailed Report ===\n")

        let psOutput = shell("/bin/ps", ["aux"])
        let psLines = psOutput.split(separator: "\n").dropFirst()

        var foundPIDs: [Int32] = []
        for line in psLines {
            let l = String(line).lowercased()
            guard l.contains(name.lowercased()) else { continue }
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 11,
                  let pid = Int32(String(cols[1])) else { continue }

            // Exclude ghostkill itself
            if pid == ProcessInfo.processInfo.processIdentifier { continue }

            let cpu    = String(cols[2])
            let rssKB  = Int(String(cols[5])) ?? 0
            let stat   = String(cols[7])
            let start  = String(cols[8])
            let time   = String(cols[9])
            let cmd    = cols[10...].joined(separator: " ")

            lines.append("PID: \(pid)")
            lines.append("  Command:  \(cmd)")
            lines.append("  CPU:      \(cpu)%")
            lines.append("  Memory:   \(String(format: "%.1f", Double(rssKB) / 1024.0))MB")
            lines.append("  State:    \(stat)")
            lines.append("  Started:  \(start)  Runtime: \(time)")

            // Check port occupancy
            let lsofOut = shell("/usr/sbin/lsof", ["-p", "\(pid)", "-i"])
            let ports = lsofOut.split(separator: "\n").dropFirst()
                .filter { $0.contains("LISTEN") || $0.contains("ESTABLISHED") }
            if !ports.isEmpty {
                lines.append("  Ports:")
                for p in ports {
                    lines.append("    \(p)")
                }
            } else {
                lines.append("  Ports: none")
            }
            lines.append("")
            foundPIDs.append(pid)
        }

        if foundPIDs.isEmpty {
            lines.append("No '\(name)' process found.")
        } else {
            lines.append("Total \(foundPIDs.count) process(es) found")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Time Machine backup detection

    static func scanTimeMachine() -> [Issue] {
        let output = shell("/usr/bin/tmutil", ["status"])
        guard !output.isEmpty else { return [] }

        // Running = 1 means backup in progress
        guard output.contains("Running = 1") else { return [] }

        // Parse progress (if available)
        var progressInfo = ""
        for line in output.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("Percent =") {
                let val = l.replacingOccurrences(of: "Percent = ", with: "")
                    .replacingOccurrences(of: ";", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let pct = Double(val) {
                    progressInfo = " (\(String(format: "%.0f", pct * 100))% complete)"
                }
            }
        }

        return [Issue(
            description: "Time Machine backup in progress\(progressInfo) - system may be slow",
            pids: [],
            tag: "timemachine"
        )]
    }

    // MARK: - Helpers

    static func findPIDs(pattern: String) -> [Int32] {
        let output = shell("/usr/bin/pgrep", ["-f", pattern])
        return output.split(separator: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    @discardableResult
    static func shell(_ executable: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

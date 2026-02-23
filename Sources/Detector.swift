import Foundation

struct Issue {
    let description: String
    let pids: [Int32]
    let tag: String
}

enum Detector {
    // IDE가 남기는 좀비 터미널 패턴
    static let zombiePatterns: [(pattern: String, label: String)] = [
        ("kiro-cli-term",     "Kiro CLI"),
        ("cursor-cli-term",   "Cursor"),
        ("vscode-cli-term",   "VS Code"),
        ("windsurf-cli-term", "Windsurf"),
    ]

    // 중복 실행 감지 대상
    static let duplicateTargets: [(name: String, threshold: Int)] = [
        ("claude", 5),
        ("node",   10),
        ("bun",    5),
    ]

    // 개발용 포트 목록
    static let devPorts: [Int] = [3000, 3001, 4000, 5000, 5173, 8000, 8080, 8888, 9000]

    // 고아 프로세스 제외 시스템 프로세스
    static let systemProcessExclusions: Set<String> = [
        "launchd", "kernel_task", "UserEventAgent", "loginwindow", "WindowServer",
        "mds", "mds_stores", "mdworker", "distnoted", "cfprefsd", "lsd",
        "configd", "opendirectoryd", "syspolicyd", "trustd", "SecurityAgent",
        "coreaudiod", "sharingd", "syslogd", "notifyd", "logd", "powerd",
        "airportd", "bluetoothd", "locationd", "nsurlsessiond", "nsurlstoraged",
        "rapportd", "rtcreportingd", "spindump", "osanalyticshelper",
        "thermald", "secd", "akd", "nsurlsessiond", "coreduetd",
    ]

    static func scan() -> [Issue] {
        var issues: [Issue] = []

        // 1. 좀비 터미널 세션 감지
        for z in zombiePatterns {
            let pids = findPIDs(pattern: z.pattern)
            if !pids.isEmpty {
                issues.append(Issue(
                    description: "\(z.label) 좀비 터미널 세션 \(pids.count)개 발견",
                    pids: pids,
                    tag: "zombie"
                ))
            }
        }

        // 2. 중복 프로세스 감지
        for d in duplicateTargets {
            let pids = findPIDs(pattern: d.name)
            if pids.count >= d.threshold {
                issues.append(Issue(
                    description: "\(d.name) 인스턴스 \(pids.count)개 실행 중 (기준: \(d.threshold)개)",
                    pids: pids,
                    tag: "duplicate"
                ))
            }
        }

        // 3. launchctl 에이전트 감지
        let launchctlIssues = scanLaunchctl()
        issues.append(contentsOf: launchctlIssues)

        // 4. 높은 CPU/메모리 점유 프로세스 감지
        let resourceIssues = scanHighResourceProcesses()
        issues.append(contentsOf: resourceIssues)

        // 5. 좀비 프로세스 (Z 상태) 감지
        let zombieStateIssues = scanZombieStateProcesses()
        issues.append(contentsOf: zombieStateIssues)

        // 6. 고아 프로세스 감지
        let orphanIssues = scanOrphanProcesses()
        issues.append(contentsOf: orphanIssues)

        // 7. 포트 점유 프로세스 추적
        let portIssues = scanPortOccupancy()
        issues.append(contentsOf: portIssues)

        // 8. 터미널 세션별 실행 중인 명령어 파악
        let terminalIssues = scanTerminalSessions()
        issues.append(contentsOf: terminalIssues)

        // 9. nvm/rbenv/pyenv 버전 충돌 감지
        let versionIssues = scanVersionMismatches()
        issues.append(contentsOf: versionIssues)

        // 10. macOS 시스템 레벨 감지
        let loginItemIssues = scanLoginItems()
        issues.append(contentsOf: loginItemIssues)

        let spotlightIssues = scanSpotlightOverload()
        issues.append(contentsOf: spotlightIssues)

        let launchAgentIssues = scanLaunchAgentsDirectory()
        issues.append(contentsOf: launchAgentIssues)

        return issues
    }

    // 알려진 불필요한 launchctl 에이전트 prefix
    static let launchctlPrefixes: [(prefix: String, label: String)] = [
        ("com.kiro",           "Kiro"),
        ("com.cursor",         "Cursor"),
        ("com.adobe",          "Adobe"),
        ("com.google.keystone", "Google Keystone 업데이트"),
    ]

    static func scanLaunchctl() -> [Issue] {
        let output = shell("/bin/launchctl", ["list"])
        guard !output.isEmpty else { return [] }

        var issues: [Issue] = []
        for entry in launchctlPrefixes {
            let matched = output.split(separator: "\n").filter { $0.contains(entry.prefix) }
            if !matched.isEmpty {
                issues.append(Issue(
                    description: "\(entry.label) launchctl 에이전트 \(matched.count)개 감지됨 (\(entry.prefix)*)",
                    pids: [],
                    tag: "launchctl"
                ))
            }
        }
        return issues
    }

    // MARK: - 높은 CPU/메모리 점유 프로세스 감지

    static func scanHighResourceProcesses() -> [Issue] {
        // ps aux: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
        let output = shell("/bin/ps", ["aux"])
        var issues: [Issue] = []

        for line in output.split(separator: "\n").dropFirst() {
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
                    description: "\(command) CPU \(String(format: "%.1f", cpu))% 점유 중",
                    pids: [pid],
                    tag: "resource"
                ))
            } else if memMB > 500.0 {
                issues.append(Issue(
                    description: "\(command) 메모리 \(String(format: "%.0f", memMB))MB 점유 중",
                    pids: [pid],
                    tag: "resource"
                ))
            }
        }
        return issues
    }

    // MARK: - 좀비 프로세스 (Z 상태) 감지

    static func scanZombieStateProcesses() -> [Issue] {
        let output = shell("/bin/ps", ["aux"])
        var zombiePIDs: [Int32] = []

        for line in output.split(separator: "\n").dropFirst() {
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
            description: "좀비 프로세스 \(zombiePIDs.count)개 감지 (Z 상태)",
            pids: zombiePIDs,
            tag: "zombie-state"
        )]
    }

    // MARK: - 고아 프로세스 감지 (PPID == 1, 일반 사용자 프로세스)

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

            // 시스템 프로세스 제외
            guard !systemProcessExclusions.contains(comm) else { continue }
            // root 및 시스템 계정 제외
            guard user != "root" && user != "_" && !user.hasPrefix("_") else { continue }
            // 현재 사용자 프로세스만 포함
            guard user == currentUser else { continue }

            orphanPIDs.append(pid)
        }

        guard !orphanPIDs.isEmpty else { return [] }
        return [Issue(
            description: "고아 프로세스 \(orphanPIDs.count)개 감지 (PPID=1, 일반 사용자)",
            pids: orphanPIDs,
            tag: "orphan"
        )]
    }

    // MARK: - 포트 점유 프로세스 추적

    static func scanPortOccupancy() -> [Issue] {
        var issues: [Issue] = []

        for port in devPorts {
            let output = shell("/usr/sbin/lsof", ["-ti", ":\(port)"])
            let pids = output.split(separator: "\n")
                .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            guard !pids.isEmpty else { continue }

            // 프로세스 이름 조회
            let firstPID = pids[0]
            let commOut = shell("/bin/ps", ["-p", "\(firstPID)", "-o", "comm="])
            let procName = commOut.trimmingCharacters(in: .whitespacesAndNewlines)

            issues.append(Issue(
                description: "포트 \(port) 점유: \(procName) (PID \(firstPID))",
                pids: pids,
                tag: "port"
            ))
        }
        return issues
    }

    // MARK: - 터미널 세션별 실행 중인 명령어

    static func scanTerminalSessions() -> [Issue] {
        let output = shell("/bin/ps", ["aux"])
        // tty 컬럼(cols[6])이 s000~s999 형태인 프로세스
        var sessionMap: [String: [(pid: Int32, comm: String)]] = [:]

        for line in output.split(separator: "\n").dropFirst() {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 11 else { continue }
            let pidStr  = String(cols[1])
            let tty     = String(cols[6])
            let command = cols[10...].joined(separator: " ")

            guard tty.hasPrefix("s"), tty.count == 4,
                  tty.dropFirst().allSatisfy({ $0.isNumber }),
                  let pid = Int32(pidStr) else { continue }

            // zsh/bash/sh 제외
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
                description: "터미널 \(tty): \(desc)",
                pids: procs.map { $0.pid },
                tag: "terminal-session"
            ))
        }
        return issues
    }

    // MARK: - nvm/rbenv/pyenv 버전 충돌 감지

    static func scanVersionMismatches() -> [Issue] {
        var issues: [Issue] = []
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""

        // Node.js 버전 확인
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
                    description: "Node.js 버전 불일치 - 현재: \(actual), 기대: \(expected)",
                    pids: [],
                    tag: "version-mismatch"
                ))
            }
        }

        // Ruby 버전 확인
        let rubyVersionPath = "\(home)/.ruby-version"
        if let expected = try? String(contentsOfFile: rubyVersionPath, encoding: .utf8) {
            let expectedTrimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)
            let actual = shell("/usr/bin/env", ["ruby", "--version"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !actual.isEmpty && !actual.contains(expectedTrimmed) {
                issues.append(Issue(
                    description: "Ruby 버전 불일치 - 현재: \(actual), 기대: \(expectedTrimmed)",
                    pids: [],
                    tag: "version-mismatch"
                ))
            }
        }

        // Python 버전 확인
        let pythonVersionPath = "\(home)/.python-version"
        if let expected = try? String(contentsOfFile: pythonVersionPath, encoding: .utf8) {
            let expectedTrimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)
            let actual = shell("/usr/bin/env", ["python3", "--version"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !actual.isEmpty && !actual.contains(expectedTrimmed) {
                issues.append(Issue(
                    description: "Python 버전 불일치 - 현재: \(actual), 기대: \(expectedTrimmed)",
                    pids: [],
                    tag: "version-mismatch"
                ))
            }
        }

        return issues
    }

    // MARK: - macOS Login Items 스캔

    static func scanLoginItems() -> [Issue] {
        let output = shell("/usr/bin/osascript", [
            "-e", "tell application \"System Events\" to get the name of every login item"
        ])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let items = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return [Issue(
            description: "Login Items \(items.count)개 등록됨: \(items.joined(separator: ", "))",
            pids: [],
            tag: "login-item"
        )]
    }

    // MARK: - Spotlight 과부하 감지

    static func scanSpotlightOverload() -> [Issue] {
        let output = shell("/bin/ps", ["aux"])
        var issues: [Issue] = []

        for line in output.split(separator: "\n") {
            guard line.contains("mds_stores") else { continue }
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 3,
                  let pid = Int32(String(cols[1])),
                  let cpu = Double(String(cols[2])),
                  cpu > 50.0 else { continue }

            issues.append(Issue(
                description: "Spotlight(mds_stores) CPU \(String(format: "%.1f", cpu))% 과부하",
                pids: [pid],
                tag: "resource"
            ))
        }
        return issues
    }

    // MARK: - LaunchAgents 디렉토리 스캔

    static func scanLaunchAgentsDirectory() -> [Issue] {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let launchAgentsPath = "\(home)/Library/LaunchAgents"

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: launchAgentsPath) else { return [] }

        let plists = files.filter { $0.hasSuffix(".plist") }
        guard !plists.isEmpty else { return [] }

        return [Issue(
            description: "~/Library/LaunchAgents에 plist \(plists.count)개 등록됨",
            pids: [],
            tag: "launch-agent"
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

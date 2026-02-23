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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var issues: [Issue] = []
        for entry in launchctlPrefixes {
            let matched = output.split(separator: "\n").filter { line in
                line.contains(entry.prefix)
            }.map { String($0) }

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

    static func findPIDs(pattern: String) -> [Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", pattern]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output
            .split(separator: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }
}

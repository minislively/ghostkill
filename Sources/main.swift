import Foundation

let version = "0.1.0"

func main() {
    let args = CommandLine.arguments.dropFirst()

    if args.contains("--version") || args.contains("-v") {
        print("ghostkill v\(version)")
        return
    }

    if args.contains("--help") || args.contains("-h") {
        printHelp()
        return
    }

    let fix = args.contains("--fix") || args.contains("-f")
    let watch = args.contains("--watch") || args.contains("-w")

    if watch {
        runWatch()
        return
    }

    print("🔍 스캔 중...\n")
    let issues = Detector.scan()

    if issues.isEmpty {
        print("✓ 환경이 깨끗합니다.")
        return
    }

    printGrouped(issues: issues)

    if fix {
        print()
        let killed = Killer.fix(issues: issues)
        print("→ \(killed)개 프로세스 정리 완료")
    } else {
        print("\n→ 정리하려면: ghostkill --fix")
    }
}

func printGrouped(issues: [Issue]) {
    let categories: [(tag: String, label: String)] = [
        ("zombie",           "좀비 터미널 세션"),
        ("zombie-state",     "좀비 프로세스 (Z 상태)"),
        ("duplicate",        "중복 프로세스"),
        ("resource",         "높은 CPU/메모리 점유"),
        ("orphan",           "고아 프로세스"),
        ("port",             "포트 점유"),
        ("terminal-session", "터미널 세션"),
        ("version-mismatch", "버전 불일치"),
        ("launchctl",        "LaunchCtl 에이전트"),
        ("launch-agent",     "LaunchAgents"),
        ("login-item",       "Login Items"),
        ("timemachine",      "Time Machine"),
    ]

    var printed = Set<String>()

    for cat in categories {
        let group = issues.filter { $0.tag == cat.tag }
        guard !group.isEmpty else { continue }
        print("[\(cat.label)]")
        for issue in group {
            print("  ⚠ \(issue.description)")
        }
        print()
        printed.insert(cat.tag)
    }

    // 분류되지 않은 나머지
    let rest = issues.filter { !printed.contains($0.tag) }
    if !rest.isEmpty {
        print("[기타]")
        for issue in rest {
            print("  ⚠ \(issue.description)")
        }
        print()
    }
}

func runWatch() {
    print("👁 watch 모드 시작 (Ctrl+C로 종료, 5초마다 스캔)\n")

    var previousDescriptions: Set<String> = []

    signal(SIGINT) { _ in
        print("\n종료합니다.")
        exit(0)
    }

    while true {
        let issues = Detector.scan()
        let currentDescriptions = Set(issues.map { $0.description })
        let newDescriptions = currentDescriptions.subtracting(previousDescriptions)

        if !newDescriptions.isEmpty {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            print("[\(timestamp)] 새로운 이슈 감지:")
            for issue in issues where newDescriptions.contains(issue.description) {
                print("  ⚠ \(issue.description)")
            }
            print()
        }

        previousDescriptions = currentDescriptions
        Thread.sleep(forTimeInterval: 5)
    }
}

func printHelp() {
    print("""
ghostkill - macOS 프로세스 환경 진단 및 정리

사용법:
  ghostkill           현재 환경 진단
  ghostkill --fix     문제 프로세스 자동 정리
  ghostkill --watch   5초마다 반복 스캔 (새 이슈만 출력)
  ghostkill --version 버전 출력

감지 항목:
  [zombie]           IDE가 남긴 좀비 터미널 세션 (Kiro, Cursor, VS Code, Windsurf)
  [zombie-state]     ps Z 상태 좀비 프로세스 (--fix 대상)
  [duplicate]        claude/node/bun 등 과도한 중복 프로세스
  [resource]         CPU > 80% 또는 메모리 > 500MB 점유 프로세스 (--fix 대상)
  [orphan]           PPID=1 고아 프로세스 (skip - 위험할 수 있음)
  [port]             개발용 포트(3000,3001,4000,5000,5173,8000,8080,8888,9000) 점유 (skip)
  [terminal-session] 터미널 세션별 실행 중인 foreground 명령어 (정보성)
  [version-mismatch] nvm/rbenv/pyenv 버전 파일과 실제 버전 불일치 (정보성)
  [launchctl]        불필요한 launchctl 에이전트 (Adobe, Google Keystone 등)
  [launch-agent]     ~/Library/LaunchAgents plist 목록
  [login-item]       시스템 Login Items 목록

--fix 대상: zombie, zombie-state, resource
skip 대상:  orphan, port, terminal-session, version-mismatch, launchctl, launch-agent, login-item, duplicate

GitHub: https://github.com/minislively/ghostkill
""")
}

main()

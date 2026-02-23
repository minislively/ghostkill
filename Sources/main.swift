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

    for issue in issues {
        print("⚠ \(issue.description)")
    }

    if fix {
        print()
        let killed = Killer.fix(issues: issues)
        print("→ \(killed)개 프로세스 정리 완료")
    } else {
        print("\n→ 정리하려면: ghostkill --fix")
    }
}

func runWatch() {
    print("👁 watch 모드 시작 (Ctrl+C로 종료, 5초마다 스캔)\n")

    var previousDescriptions: Set<String> = []

    // Ctrl+C 핸들러
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

GitHub: https://github.com/minislively/ghostkill
""")
}

main()

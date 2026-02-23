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

func printHelp() {
    print("""
ghostkill - macOS 프로세스 환경 진단 및 정리

사용법:
  ghostkill           현재 환경 진단
  ghostkill --fix     문제 프로세스 자동 정리
  ghostkill --version 버전 출력

GitHub: https://github.com/minislively/ghostkill
""")
}

main()

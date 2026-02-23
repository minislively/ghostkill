import Foundation

enum Killer {
    static func fix(issues: [Issue]) -> Int {
        var killed = 0
        for issue in issues {
            switch issue.tag {
            case "zombie", "zombie-state", "resource":
                // 명시적으로 안전하다고 알려진 태그만 kill
                for pid in issue.pids {
                    if kill(pid, SIGKILL) == 0 {
                        killed += 1
                    }
                }
            case "duplicate", "launchctl", "launch-agent", "login-item":
                print("  skip: \(issue.description) (수동으로 확인 필요)")
            case "orphan":
                print("  skip: \(issue.description) (고아 프로세스 - 위험할 수 있어 수동 확인 필요)")
            case "port":
                print("  skip: \(issue.description) (포트 점유 - 사용자 확인 필요)")
            case "terminal-session":
                print("  skip: \(issue.description) (정보성)")
            case "version-mismatch":
                print("  skip: \(issue.description) (정보성 - 버전 설정 확인 필요)")
            default:
                // 알 수 없는 태그는 안전하게 skip - 새 감지기 태그가 실수로 kill되지 않도록
                print("  skip: \(issue.description) (알 수 없는 태그 '\(issue.tag)' - 명시적 승인 필요)")
            }
        }
        return killed
    }
}

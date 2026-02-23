import Foundation

enum Killer {
    static func fix(issues: [Issue]) -> Int {
        var killed = 0
        for issue in issues {
            // duplicate, launchctl는 자동 kill 하지 않음
            if issue.tag == "duplicate" || issue.tag == "launchctl" {
                print("  skip: \(issue.description) (수동으로 확인 필요)")
                continue
            }
            for pid in issue.pids {
                if kill(pid, SIGKILL) == 0 {
                    killed += 1
                }
            }
        }
        return killed
    }
}

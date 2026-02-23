import Foundation

enum Killer {
    static func fix(issues: [Issue]) -> Int {
        var killed = 0
        for issue in issues {
            switch issue.tag {
            case "zombie", "zombie-state", "resource":
                // Only kill tags explicitly known to be safe
                for pid in issue.pids {
                    if kill(pid, SIGKILL) == 0 {
                        killed += 1
                    }
                }
            case "duplicate", "launchctl", "launch-agent", "login-item":
                print("  skip: \(issue.description) (requires manual review)")
            case "orphan":
                print("  skip: \(issue.description) (orphan process - may be dangerous, requires manual review)")
            case "port":
                print("  skip: \(issue.description) (port occupancy - requires user confirmation)")
            case "terminal-session":
                print("  skip: \(issue.description) (informational)")
            case "version-mismatch":
                print("  skip: \(issue.description) (informational - check version configuration)")
            case "network", "disk", "temperature":
                print("  skip: \(issue.description) (informational)")
            default:
                // Unknown tags are skipped safely - prevents new detector tags from being killed accidentally
                print("  skip: \(issue.description) (unknown tag '\(issue.tag)' - explicit approval required)")
            }
        }
        return killed
    }
}

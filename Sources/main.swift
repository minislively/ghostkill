import Foundation

let version = "0.2.0"

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

    // --app <name> handling
    let argsArray = Array(args)
    if let appIdx = argsArray.firstIndex(of: "--app"), appIdx + 1 < argsArray.count {
        let appName = argsArray[appIdx + 1]
        print(Detector.scanApp(name: appName))
        return
    }

    if watch {
        runWatch()
        return
    }

    print("🔍 Scanning...\n")
    let issues = Detector.scan()

    if issues.isEmpty {
        print("✓ Everything looks clean.")
        return
    }

    printGrouped(issues: issues)

    if fix {
        print()
        let killed = Killer.fix(issues: issues)
        print("→ \(killed) process(es) cleaned up")
    } else {
        print("\n→ To clean up: ghostkill --fix")
    }
}

func printGrouped(issues: [Issue]) {
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
        ("temperature",      "System Temperature"),
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

    // Uncategorized remainder
    let rest = issues.filter { !printed.contains($0.tag) }
    if !rest.isEmpty {
        print("[Other]")
        for issue in rest {
            print("  ⚠ \(issue.description)")
        }
        print()
    }
}

func runWatch() {
    print("👁 Watch mode started (Ctrl+C to exit, scans every 5 seconds)\n")

    var previousDescriptions: Set<String> = []

    signal(SIGINT) { _ in
        print("\nExiting.")
        exit(0)
    }

    while true {
        let issues = Detector.scan()
        let currentDescriptions = Set(issues.map { $0.description })
        let newDescriptions = currentDescriptions.subtracting(previousDescriptions)

        if !newDescriptions.isEmpty {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            print("[\(timestamp)] New issues detected:")
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
ghostkill - macOS process environment diagnostics and cleanup

Usage:
  ghostkill              Diagnose current environment
  ghostkill --fix        Auto-clean problematic processes
  ghostkill --watch      Repeat scan every 5 seconds (new issues only)
  ghostkill --app <name> Detailed report for a specific app (PID, CPU, memory, ports)
  ghostkill --version    Print version

Detected items:
  [zombie]           Zombie terminal sessions left by IDEs (Kiro, Cursor, VS Code, Windsurf)
  [zombie-state]     ps Z-state zombie processes (--fix target)
  [duplicate]        Excessive duplicate processes of claude/node/bun etc.
  [resource]         Processes using CPU > 80% or memory > 500MB (--fix target)
  [orphan]           PPID=1 orphan processes (skip - may be dangerous)
  [port]             Dev port occupancy (3000,3001,4000,5000,5173,8000,8080,8888,9000) (skip)
  [terminal-session] Foreground commands running per terminal session (informational)
  [version-mismatch] nvm/rbenv/pyenv version file vs actual version mismatch (informational)
  [launchctl]        Unnecessary launchctl agents (Adobe, Google Keystone, etc.)
  [launch-agent]     ~/Library/LaunchAgents plist list
  [login-item]       System Login Items list
  [network]          No network connection or high latency (>= 200ms) (informational)
  [disk]             Root disk usage >= 85% warning (informational)

--fix targets: zombie, zombie-state, resource
skip targets:  orphan, port, terminal-session, version-mismatch, launchctl, launch-agent, login-item, duplicate, network, disk, temperature

GitHub: https://github.com/minislively/ghostkill
""")
}

main()

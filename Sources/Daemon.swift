import Foundation

enum Daemon {
    static let plistLabel = "io.ghostkill.daemon"
    static let plistFileName = "\(plistLabel).plist"

    static var plistPath: String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        return "\(home)/Library/LaunchAgents/\(plistFileName)"
    }

    static func start(interval: TimeInterval = 60) {
        let binaryPath = CommandLine.arguments[0]
        let plistContent = buildPlist(binaryPath: binaryPath, interval: Int(interval))

        // Write plist
        do {
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
            print("Plist written to: \(plistPath)")
        } catch {
            print("Error: Failed to write plist - \(error)")
            exit(1)
        }

        // launchctl load
        let result = Detector.shell("/bin/launchctl", ["load", plistPath])
        if result.lowercased().contains("error") {
            print("Warning: launchctl load reported: \(result.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        print("Daemon registered and loaded. ghostkill will run every \(Int(interval))s.")
    }

    static func stop() {
        // launchctl unload
        let result = Detector.shell("/bin/launchctl", ["unload", plistPath])
        if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("launchctl: \(result.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        // Remove plist
        let fm = FileManager.default
        if fm.fileExists(atPath: plistPath) {
            do {
                try fm.removeItem(atPath: plistPath)
                print("Plist removed: \(plistPath)")
            } catch {
                print("Error: Failed to remove plist - \(error)")
                exit(1)
            }
        } else {
            print("Plist not found (already removed): \(plistPath)")
        }
        print("Daemon stopped.")
    }

    static func status() {
        let fm = FileManager.default
        let plistExists = fm.fileExists(atPath: plistPath)

        let listOutput = Detector.shell("/bin/launchctl", ["list", plistLabel])
        let isLoaded = !listOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !listOutput.contains("Could not find")
            && !listOutput.contains("No such process")

        if isLoaded {
            print("Daemon status: RUNNING")
            print("Label:         \(plistLabel)")
            print("Plist:         \(plistPath) (\(plistExists ? "present" : "missing"))")
        } else {
            print("Daemon status: NOT RUNNING")
            print("Plist:         \(plistPath) (\(plistExists ? "present" : "missing"))")
        }
    }

    // MARK: - Notification

    static func sendNotification(title: String, message: String) {
        let script = "display notification \"\(message)\" with title \"\(title)\""
        Detector.shell("/usr/bin/osascript", ["-e", script])
    }

    // MARK: - Silent scan + notify

    static func scanAndNotify() {
        let issues = Detector.scan()
        guard !issues.isEmpty else { return }

        let zombieCount = issues.filter { $0.tag == "zombie" || $0.tag == "zombie-state" }
            .reduce(0) { $0 + max(1, $1.pids.count) }
        let resourceCount = issues.filter { $0.tag == "resource" }.count
        let total = issues.count

        var parts: [String] = []
        if zombieCount > 0 { parts.append("\(zombieCount) zombie session(s)") }
        if resourceCount > 0 { parts.append("\(resourceCount) high resource process(es)") }
        if parts.isEmpty { parts.append("\(total) issue(s)") }

        let message = parts.joined(separator: ", ") + " detected"
        sendNotification(title: "ghostkill", message: message)
    }

    // MARK: - Private

    private static func buildPlist(binaryPath: String, interval: Int) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(plistLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>--scan-notify</string>
            </array>
            <key>StartInterval</key>
            <integer>\(interval)</integer>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }
}

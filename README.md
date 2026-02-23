# ghostkill

[![Swift](https://img.shields.io/badge/Swift-6.1+-orange?logo=swift)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue?logo=apple)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A macOS process diagnostics and cleanup CLI tool that detects and removes zombie terminal sessions and duplicate processes left behind by IDEs (Kiro, Cursor, VS Code, etc.) in a single command.

## Features

- Detects zombie terminal sessions abandoned by IDE processes
- Identifies duplicate processes running beyond baseline thresholds
- Safe cleanup with optional `--fix` flag for review before action
- Fast, lightweight scanning
- Supports multiple IDEs and development tools

## Installation

### Using Homebrew

```bash
brew install minislively/tap/ghostkill
```

### Building from Source

```bash
git clone https://github.com/minislively/ghostkill
cd ghostkill
swift build -c release
cp .build/release/ghostkill /usr/local/bin/
```

### GitHub Releases

Download pre-built binaries from [GitHub Releases](https://github.com/minislively/ghostkill/releases).

## Usage

### Scan for Issues

```bash
ghostkill
```

Scans the current environment and reports detected issues without making changes.

### Fix Issues Automatically

```bash
ghostkill --fix
```

Automatically terminates problematic processes identified during the scan.

### Show Help

```bash
ghostkill --help
```

### Show Version

```bash
ghostkill --version
```

## Example Output

```
🔍 Scanning...

⚠ Kiro CLI zombie terminal sessions: 15 detected
⚠ claude instances: 21 running (baseline: 5)

→ To clean up: ghostkill --fix
```

After running with `--fix`:

```
🔍 Scanning...

⚠ Kiro CLI zombie terminal sessions: 15 detected
⚠ claude instances: 21 running (baseline: 5)

→ 18 processes cleaned up
```

## Detection Rules

| Issue | Description |
|-------|-------------|
| Zombie terminal sessions | zsh sessions left behind after IDE process termination |
| Duplicate processes | Development tools running above expected baseline count |

## Supported IDEs and Tools

- Kiro CLI
- Cursor
- VS Code
- Windsurf
- Claude

## Contributing

We welcome pull requests and issue reports! Please feel free to:

- Report bugs and suggest features via [GitHub Issues](https://github.com/minislively/ghostkill/issues)
- Submit pull requests with improvements
- Share feedback and use cases

### Development

```bash
# Build for testing
swift build

# Run tests
swift test

# Build release binary
swift build -c release
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

# ghostkill Claude Code Plugin

A Claude Code / oh-my-claudecode plugin that integrates [ghostkill](https://github.com/veluga/ghostkill) into your Claude Code sessions.

## What It Does

- **Session Start Hook**: Automatically scans your macOS environment when a Claude Code session begins. Warns you about zombie processes, resource pressure, or other issues — silently if everything is clean.
- **Pre-Tool-Use Hook** (optional): Checks for critical resource issues before heavy tool invocations (Bash, Write, Edit).
- **`/ghostkill` Skill**: A slash command to run ghostkill diagnostics on demand from within Claude Code.

## Requirements

- [ghostkill](https://github.com/veluga/ghostkill) installed and on your PATH (or at `~/.local/bin/ghostkill`)
- Claude Code with oh-my-claudecode

## Installation

```bash
cd ghostkill-plugin
./install.sh
```

The installer copies hooks to `~/.claude/hooks/` and the skill to `~/.claude/skills/`.

## Usage

### Automatic (session-start hook)

Every time you start a Claude Code session, ghostkill silently scans your environment. If issues are detected, you will see a brief warning with actionable next steps.

### Manual (slash command)

In any Claude Code session:

| Command | Action |
|---|---|
| `/ghostkill` | Full diagnostic scan |
| `/ghostkill fix` | Scan and auto-fix safe issues |
| `/ghostkill app <name>` | Detailed info for a specific process |
| `/ghostkill ai` | Generate an AI prompt for detected issues |

## File Structure

```
ghostkill-plugin/
  README.md              # This file
  install.sh             # Installer script
  hooks/
    session-start.sh     # Runs on Claude Code session start
    pre-tool-use.sh      # Optional: resource check before tool use
  skills/
    ghostkill.md         # /ghostkill slash command definition
```

## Uninstall

```bash
rm ~/.claude/hooks/ghostkill-session-start.sh
rm ~/.claude/hooks/ghostkill-pre-tool-use.sh  # if installed
rm ~/.claude/skills/ghostkill.md
```

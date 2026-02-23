# ghostkill Claude Code Plugin

[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://github.com/minislively/ghostkill)

A Claude Code plugin that integrates [ghostkill](https://github.com/minislively/ghostkill) into your Claude Code sessions — automatically scanning your macOS environment at session start and providing on-demand diagnostics via a slash command.

## What It Does

- **Session Start Hook**: Automatically scans your macOS environment when a Claude Code session begins. Warns you about zombie processes, resource pressure, or other issues — silently if everything is clean.
- **`/ghostkill` Skill**: A slash command to run ghostkill diagnostics on demand from within Claude Code.

## Requirements

- [ghostkill](https://github.com/minislively/ghostkill) binary installed and on your PATH
- Claude Code

## Installation

```
/plugin marketplace add minislively/ghostkill
/plugin install ghostkill
```

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
  README.md
  .claude-plugin/
    plugin.json
  skills/
    ghostkill/
      SKILL.md
  hooks/
    hooks.json
```

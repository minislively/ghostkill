---
name: ghostkill
description: Run ghostkill to diagnose and clean macOS process environment
triggers:
  - ghostkill
  - clean environment
  - zombie processes
  - fix processes
---

Run ghostkill to scan the current macOS environment for issues.

Usage:
- `/ghostkill` - Run full diagnostic scan
- `/ghostkill fix` - Run scan and auto-fix safe issues
- `/ghostkill app <name>` - Show detailed info for specific process
- `/ghostkill ai` - Generate AI prompt for detected issues

When the user invokes this skill:
1. Run `ghostkill` (or with appropriate flags based on the argument)
2. Show the output clearly
3. If issues found, offer to run `ghostkill --fix`
4. If complex issues, offer to run `ghostkill --ai-prompt`

Argument mapping:
- No argument -> `ghostkill`
- `fix` -> `ghostkill --fix`
- `app <name>` -> `ghostkill --app <name>`
- `ai` -> `ghostkill --ai-prompt`

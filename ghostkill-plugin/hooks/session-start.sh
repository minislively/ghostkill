#!/bin/bash
# ghostkill session-start hook
# Runs ghostkill scan when Claude Code session starts
# Only shows critical issues (zombie, resource)

GHOSTKILL=$(which ghostkill 2>/dev/null || echo "$HOME/.local/bin/ghostkill")

if [ ! -x "$GHOSTKILL" ]; then
    exit 0
fi

# Silent scan, only output if issues found
OUTPUT=$("$GHOSTKILL" 2>/dev/null)
if echo "$OUTPUT" | grep -q "⚠"; then
    echo "=== ghostkill: environment issues detected ==="
    echo "$OUTPUT" | grep "⚠" | head -5
    echo "Run 'ghostkill --fix' to clean up, or 'ghostkill' for full report."
    echo "=============================================="
fi

#!/bin/bash
# ghostkill pre-tool-use hook (optional)
# Checks resource pressure before heavy operations
# Triggered before tool invocations in Claude Code

GHOSTKILL=$(which ghostkill 2>/dev/null || echo "$HOME/.local/bin/ghostkill")

if [ ! -x "$GHOSTKILL" ]; then
    exit 0
fi

# Only check on heavy tool names (bash, write, etc.)
# TOOL_NAME is passed by Claude Code hook runtime
TOOL="${TOOL_NAME:-}"
case "$TOOL" in
    Bash|bash|Write|Edit)
        # Check for critical resource issues only
        OUTPUT=$("$GHOSTKILL" 2>/dev/null)
        if echo "$OUTPUT" | grep -q "⚠"; then
            CRITICAL=$(echo "$OUTPUT" | grep "⚠" | grep -i "memory\|cpu\|zombie" | head -3)
            if [ -n "$CRITICAL" ]; then
                echo "ghostkill warning: resource pressure detected before tool use"
                echo "$CRITICAL"
            fi
        fi
        ;;
    *)
        # Skip for lightweight tools
        exit 0
        ;;
esac

#!/bin/bash
# Install ghostkill Claude Code plugin

set -e

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"

mkdir -p "$HOOKS_DIR" "$SKILLS_DIR"

# Install hooks
cp hooks/session-start.sh "$HOOKS_DIR/ghostkill-session-start.sh"
chmod +x "$HOOKS_DIR/ghostkill-session-start.sh"

# Install pre-tool-use hook (optional)
read -p "Install pre-tool-use resource check hook? [y/N] " install_pre
if [[ "$install_pre" =~ ^[Yy]$ ]]; then
    cp hooks/pre-tool-use.sh "$HOOKS_DIR/ghostkill-pre-tool-use.sh"
    chmod +x "$HOOKS_DIR/ghostkill-pre-tool-use.sh"
    echo "pre-tool-use hook installed."
fi

# Install skill
cp skills/ghostkill.md "$SKILLS_DIR/ghostkill.md"

echo ""
echo "ghostkill Claude Code plugin installed!"
echo ""
echo "The session-start hook will automatically scan your environment"
echo "when you start a new Claude Code session."
echo ""
echo "Use /ghostkill in Claude Code to run diagnostics manually."

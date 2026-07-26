#!/usr/bin/env bash
# itr-wala installer - copies the skill into your agent's skills directory.
#
#   curl -fsSL https://raw.githubusercontent.com/karanb192/itr-wala/main/install.sh | bash              # Claude Code
#   curl -fsSL https://raw.githubusercontent.com/karanb192/itr-wala/main/install.sh | bash -s codex     # OpenAI Codex CLI
#   curl -fsSL https://raw.githubusercontent.com/karanb192/itr-wala/main/install.sh | bash -s gemini    # Gemini CLI
#   curl -fsSL https://raw.githubusercontent.com/karanb192/itr-wala/main/install.sh | bash -s all       # all of the above
#
# Prefer reading before piping? Clone and run ./install.sh - it is ~80 lines.
#
# Claude Code users can skip this entirely:
#   /plugin marketplace add karanb192/itr-wala
#   /plugin install itr-wala@itr-wala
#
# macOS and Linux. Windows: use WSL, or copy skills/itr-wala into
# %USERPROFILE%\.claude\skills manually.

set -euo pipefail

REPO="https://github.com/karanb192/itr-wala.git"
TARGET="${1:-claude}"
SKILL="itr-wala"

if [ -f "$(dirname "$0")/skills/$SKILL/SKILL.md" ]; then
  SRC="$(cd "$(dirname "$0")" && pwd)"
  echo "Installing from local checkout: $SRC"
else
  SRC="$(mktemp -d)"
  trap 'rm -rf "$SRC"' EXIT
  echo "Fetching $REPO ..."
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 --quiet "$REPO" "$SRC" || {
    echo "ERROR: could not fetch $REPO - check your network and the URL." >&2
    exit 1
  }
fi

INSTALLED=()
install_into() {
  mkdir -p "$1"
  if [ -e "$1/$SKILL" ]; then
    echo "  replacing existing install at $1/$SKILL"
    rm -rf "${1:?}/$SKILL"
  fi
  cp -R "$SRC/skills/$SKILL" "$1/$SKILL"
  find "$1/$SKILL" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
  find "$1/$SKILL" -name '*.pyc' -delete 2>/dev/null || true
  INSTALLED+=("$1/$SKILL")
  echo "  installed -> $1/$SKILL"
}

case "$TARGET" in
  claude)  install_into "$HOME/.claude/skills" ;;
  codex)
    # ~/.agents/skills is the current cross-agent standard location;
    # ~/.codex/skills is the original Codex location - cover both.
    install_into "$HOME/.agents/skills"
    install_into "${CODEX_HOME:-$HOME/.codex}/skills"
    ;;
  gemini)  install_into "$HOME/.gemini/skills" ;;
  all)
    install_into "$HOME/.claude/skills"
    install_into "$HOME/.agents/skills"
    install_into "${CODEX_HOME:-$HOME/.codex}/skills"
    install_into "$HOME/.gemini/skills"
    ;;
  *) echo "Unknown target '$TARGET' (use: claude | codex | gemini | all)"; exit 1 ;;
esac

echo
echo "Verifying the tax engine (golden test suite) in each installed copy..."
FAILED=0
for dest in "${INSTALLED[@]}"; do
  if python3 "$dest/scripts/test_tax_engine.py" >/dev/null 2>&1; then
    echo "  OK   $dest"
  else
    echo "  FAIL $dest - run: python3 $dest/scripts/test_tax_engine.py" >&2
    FAILED=1
  fi
done
if [ "$FAILED" -ne 0 ]; then
  echo "WARNING: verification failed (is python3 3.9+ on PATH?). Do not trust the skill until the self-test passes." >&2
fi

echo
echo "Done. Restart your CLI, then say: \"file my ITR\" (Claude: /itr-wala, Codex: \$itr-wala)"
exit "$FAILED"

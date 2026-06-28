#!/usr/bin/env bash
#
# sync-skills.sh
# Mirrors project-level skills from .agents/skills/ -> .claude/skills/
#
# Works on macOS, Linux, and Windows (via Git Bash, which ships with Git
# for Windows). Run it from anywhere; it always operates on the project
# root, i.e. the directory this script lives in.
#
# NOTE: This performs a MIRROR sync. Anything in .claude/skills/ that is
# not in .agents/skills/ will be deleted. Treat .agents/skills/ as the
# single source of truth and never edit .claude/skills/ directly.

set -euo pipefail

# --- Resolve project root (the directory containing this script) -------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$PROJECT_ROOT/.agents/skills"
DEST="$PROJECT_ROOT/.claude/skills"

# --- Sanity checks ------------------------------------------------------------
if [ ! -d "$SRC" ]; then
  echo "Error: source directory not found: $SRC" >&2
  echo "Nothing to sync. Is this script in the project root?" >&2
  exit 1
fi

# Refuse to clobber a symlink (e.g. leftover from an earlier symlink setup).
if [ -L "$DEST" ]; then
  echo "Error: $DEST is a symlink. Remove it first, then re-run:" >&2
  echo "  rm \"$DEST\"" >&2
  exit 1
fi

# --- Mirror sync --------------------------------------------------------------
echo "Syncing skills"
echo "  from: $SRC"
echo "  to:   $DEST"

# Remove the old destination entirely so deleted/renamed skills don't linger.
rm -rf "$DEST"
mkdir -p "$DEST"

# Copy contents (including dotfiles). The trailing /. copies the contents of
# SRC rather than the directory itself, and picks up hidden files portably.
cp -R "$SRC/." "$DEST/"

# --- Report -------------------------------------------------------------------
count=$(find "$DEST" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')
echo "Done. $count skill folder(s) now in .claude/skills/:"
find "$DEST" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/  - /'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                
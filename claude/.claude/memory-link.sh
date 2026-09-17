#!/bin/sh
# Point every project's Claude Code auto memory at the synced folder.
#
# Claude Code keeps auto memory in ~/.claude/projects/<project>/memory/ and never
# shares it between machines. This replaces each of those directories with a
# symlink into iCloud Drive, so both machines read and write the same notes.
#
# Idempotent: safe to run on every session start.

set -eu

SYNC_ROOT="${CLAUDE_MEMORY_SYNC_ROOT:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Config}"
SYNC_DIR="$SYNC_ROOT/Claude/memory"
PROJECTS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"

# The synced root has to already exist, otherwise we would quietly build a
# plain local directory that never reaches the other machine.
[ -d "$SYNC_ROOT" ] || exit 0

mkdir -p "$SYNC_DIR" "$PROJECTS_DIR"

link_project() {
	project=$1
	target="$SYNC_DIR/$project"
	link="$PROJECTS_DIR/$project/memory"

	if [ -L "$link" ]; then
		if [ "$(readlink "$link")" != "$target" ]; then
			echo "claude-memory-link: $link already points somewhere else, skipping" >&2
			return
		fi
		mkdir -p "$target"
		return
	fi

	mkdir -p "$PROJECTS_DIR/$project" "$target"

	if [ -d "$link" ]; then
		if [ -z "$(ls -A "$link")" ]; then
			rmdir "$link"
		else
			# Never clobber notes the other machine already synced.
			cp -Rn "$link"/. "$target"/ 2>/dev/null || true
			backup="$PROJECTS_DIR/$project/memory.replaced-$(date +%Y%m%d%H%M%S)"
			mv "$link" "$backup"
			echo "claude-memory-link: merged local memory of $project into the sync folder (old copy: $backup)" >&2
		fi
	fi

	ln -s "$target" "$link"
}

for dir in "$PROJECTS_DIR"/*/; do
	[ -d "$dir" ] || continue
	link_project "$(basename "$dir")"
done

# Projects that so far only exist on the other machine.
for dir in "$SYNC_DIR"/*/; do
	[ -d "$dir" ] || continue
	link_project "$(basename "$dir")"
done

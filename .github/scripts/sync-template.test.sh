#!/usr/bin/env bash
# sync-template.sh, run for real against two throwaway repositories: a
# template that moves, and a copy made from it the way "Use this template"
# makes one, with the template's files and none of its history.
#
# Each case is something a copy's owner would otherwise find out from a
# pull request that took their work away, or from one that never came.
# Nothing here reaches the network.
set -euo pipefail

script="$(cd "$(dirname "$0")" && pwd)/sync-template.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset GITHUB_OUTPUT RUNNER_TEMP

failed=0
check() {
  if [ "$2" = "$3" ]; then echo "  ok    $1"; else echo "  FAIL  $1"; echo "        wanted: $3"; echo "        got:    $2"; failed=1; fi
}
has() {
  if printf '%s' "$2" | grep -Fq -- "$3"; then echo "  ok    $1"; else echo "  FAIL  $1"; echo "        no \"$3\" in:"; printf '%s\n' "$2" | sed 's/^/          /'; failed=1; fi
}
commit() { git -C "$1" add -A && git -C "$1" commit --quiet -m "$2"; }
# What the sync printed, by name.
said() { printf '%s\n' "$out" | sed -n "s/^$1=//p"; }
sync() { out="$(cd "$tmp/copy" && UPSTREAM=acme/templates UPSTREAM_URL="$tmp/template" bash "$script")"; }
# The pull request, merged: the copy's branch moves to the commit it was given.
merge() { git -C "$tmp/copy" reset --quiet --hard "$(said commit)"; }

# The template, as it was when the copy was made.
git init --quiet --initial-branch=main "$tmp/template"
mkdir -p "$tmp/template/.claude/skills/one" "$tmp/template/.github/workflows"
printf 'line one\nline two\nline three\n' > "$tmp/template/.claude/skills/one/SKILL.md"
printf '{ "extends": ["github>acme/templates"] }\n' > "$tmp/template/renovate.json"
printf 'on: push\n' > "$tmp/template/.github/workflows/check.yml"
printf 'the template\n' > "$tmp/template/README.md"
commit "$tmp/template" 'the template'

# The copy: the same files, a history of its own.
git init --quiet --initial-branch=main "$tmp/copy"
git -C "$tmp/template" archive HEAD | tar -x -C "$tmp/copy"
commit "$tmp/copy" 'Initial commit'

echo 'a copy that has everything'
sync
check 'says there is nothing to take' "$(said changed)" false

echo 'the template moves, and the copy has changed other things'
printf '{ "extends": ["github>me/mine"] }\n' > "$tmp/copy/renovate.json"
printf 'mine alone\n' > "$tmp/copy/notes.md"
commit "$tmp/copy" 'my owner, and a file of my own'
mkdir -p "$tmp/template/.claude/skills/two"
printf 'a new skill\n' > "$tmp/template/.claude/skills/two/SKILL.md"
printf 'line one\nline two\nline three, improved\n' > "$tmp/template/.claude/skills/one/SKILL.md"
printf 'on: [push, pull_request]\n' > "$tmp/template/.github/workflows/check.yml"
commit "$tmp/template" 'a second skill, a better first one, a wider check'
sync
new="$(said commit)"
check 'a pull request is called for' "$(said changed)" true
check 'on top of the copy as it is' "$(git -C "$tmp/copy" rev-parse "$new^")" "$(git -C "$tmp/copy" rev-parse HEAD)"
check 'the new skill came in' "$(git -C "$tmp/copy" show "$new:.claude/skills/two/SKILL.md")" 'a new skill'
check 'the changed skill came in' "$(git -C "$tmp/copy" show "$new:.claude/skills/one/SKILL.md" | tail -1)" 'line three, improved'
check 'the owner the copy wrote is still its own' "$(git -C "$tmp/copy" show "$new:renovate.json")" '{ "extends": ["github>me/mine"] }'
check 'the file the copy added is still there' "$(git -C "$tmp/copy" show "$new:notes.md")" 'mine alone'
check 'the workflow is as the copy had it' "$(git -C "$tmp/copy" show "$new:.github/workflows/check.yml")" 'on: push'
has 'and is listed to change by hand' "$(cat "$(said body)")" '.github/workflows/check.yml'
check 'where it now stands is written down' "$(git -C "$tmp/copy" show "$new:.github/template-sync" | grep -v '^#')" "$(git -C "$tmp/template" rev-parse HEAD)"
check 'nothing is left in the working tree' "$(git -C "$tmp/copy" status --porcelain)" ''

echo 'merged, and asked again'
merge
sync
check 'says there is nothing to take' "$(said changed)" false

echo 'both changed the same line'
printf 'line one\nline two, my way\nline three, improved\n' > "$tmp/copy/.claude/skills/one/SKILL.md"
commit "$tmp/copy" 'my wording'
printf 'line one\nline two, their way\nline three, improved\n' > "$tmp/template/.claude/skills/one/SKILL.md"
printf 'the template, second edition\n' > "$tmp/template/README.md"
commit "$tmp/template" 'their wording, and a README'
sync
new="$(said commit)"
check 'the copy keeps its own' "$(git -C "$tmp/copy" show "$new:.claude/skills/one/SKILL.md" | sed -n 2p)" 'line two, my way'
has 'and the file is listed as left' "$(cat "$(said body)")" 'Left as yours'
has 'by name' "$(cat "$(said body)")" '.claude/skills/one/SKILL.md'
check 'what did not clash still came in' "$(git -C "$tmp/copy" show "$new:README.md")" 'the template, second edition'
check 'no conflict marker is in any file' "$(git -C "$tmp/copy" grep -c '^<<<<<<<' "$new" -- . || true)" ''

echo 'merged, and asked again'
merge
sync
check 'the clash is not raised a second time' "$(said changed)" false

echo 'a repository with nothing in common'
rm -rf "$tmp/copy"
git init --quiet --initial-branch=main "$tmp/copy"
mkdir -p "$tmp/copy/.claude/skills/one"
printf 'written here\n' > "$tmp/copy/.claude/skills/one/SKILL.md"
commit "$tmp/copy" 'never a copy'
sync
new="$(said commit)"
check 'a file both have is left as it is here' "$(git -C "$tmp/copy" show "$new:.claude/skills/one/SKILL.md")" 'written here'
check 'a file only the template has comes in' "$(git -C "$tmp/copy" show "$new:.claude/skills/two/SKILL.md")" 'a new skill'
check 'a workflow does not' "$(git -C "$tmp/copy" ls-tree -r --name-only "$new" -- .github/workflows)" ''
has 'and the pull request says why so little was merged' "$(cat "$(said body)")" 'nothing in common was found'

echo 'an upstream that is not an owner and a repository'
if (cd "$tmp/copy" && UPSTREAM='acme/templates; rm -rf /' UPSTREAM_URL="$tmp/template" bash "$script") > /dev/null 2>&1; then refused=no; else refused=yes; fi
check 'is refused' "$refused" yes

if [ "$failed" = 0 ]; then echo 'sync-template.sh does what it says'; else echo 'sync-template.sh failed a case above'; exit 1; fi

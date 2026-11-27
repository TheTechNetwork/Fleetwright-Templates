#!/usr/bin/env bash
# What the template has that this copy does not, merged as one commit for a
# person to read.
#
# A repository made with "Use this template" starts with the template's
# files and none of its history, so there is nothing for `git pull` to pull
# and nothing that says the template has moved. This works out what moved
# and merges it three ways:
#
#   base    the template commit this copy last took. Written down in
#           .github/template-sync by each sync. Before the first one it is
#           found: the template commit whose files are exactly this copy's
#           first commit, which is what "Use this template" made.
#   ours    this repository's default branch
#   theirs  the template's default branch, now
#
# So a line you changed and the template did not stays yours, a line the
# template changed and you did not comes in, and a file you added is never
# looked at.
#
# TWO THINGS IT WILL NOT DO, and it says so in the pull request each time.
#
#   Where both changed the same lines, YOURS IS KEPT and the file is listed
#   with a link to the template's version. A skill is instructions an agent
#   follows; one with conflict markers in it, merged on a busy day, is worse
#   than one that is a release behind.
#
#   NO WORKFLOW IS CHANGED. The token a workflow runs on is not allowed to
#   push a change to a workflow, and GitHub refuses the whole push if one is
#   in it. A workflow the template changed is listed, to be copied by hand.
#   That is why the logic is here and not in the workflow: this file the
#   sync can bring up to date.
#
# It writes a commit and the words for a pull request, and pushes nothing.
# The workflow does that with what this prints, and sync-template.test.sh
# runs this same file against two throwaway repositories.
#
#   UPSTREAM       owner/repo of the template    (TheTechNetwork/Fleetwright-Templates)
#   UPSTREAM_URL   where to fetch it from        (https://github.com/$UPSTREAM.git)
#   GITHUB_OUTPUT  changed, commit, title and body are written there too
set -euo pipefail

upstream="${UPSTREAM:-TheTechNetwork/Fleetwright-Templates}"
if ! printf '%s' "$upstream" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
  echo "::error::UPSTREAM is \"$upstream\"; it should be an owner and a repository, as owner/repo" >&2
  exit 2
fi
url="${UPSTREAM_URL:-https://github.com/$upstream.git}"
record=.github/template-sync
workflows=.github/workflows
work="$(mktemp -d)"
body="${RUNNER_TEMP:-$work}/template-sync.md"

emit() {
  printf '%s=%s\n' "$1" "$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; fi
}
nothing() {
  echo "$1"
  emit changed false
  exit 0
}

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
  echo "::error::this checkout is shallow, so its first commit cannot be read; check out with fetch-depth: 0" >&2
  exit 2
fi

git fetch --quiet --no-tags "$url" HEAD
theirs="$(git rev-parse FETCH_HEAD)"

# WHERE THIS COPY LAST STOOD.
base=''
how=''
if git cat-file -e "HEAD:$record" 2>/dev/null; then
  noted="$(git show "HEAD:$record" | grep -v '^#' | tr -d '[:space:]' || true)"
  if [ -n "$noted" ] && git cat-file -e "$noted^{commit}" 2>/dev/null && git merge-base --is-ancestor "$noted" "$theirs"; then
    base="$noted"
    how="the commit \`$record\` names"
  else
    echo "::warning::$record names \"$noted\", which is not a commit of $upstream; looking for where this copy began instead"
  fi
fi
if [ -z "$base" ]; then
  # Newest first, and every match kept to its end: two commits can hold the
  # same files, and either is the same base.
  history="$(git log --format='%H %T' "$theirs")"
  for root in $(git rev-list --max-parents=0 HEAD); do
    tree="$(git rev-parse "$root^{tree}")"
    base="$(printf '%s\n' "$history" | awk -v t="$tree" '$2 == t && !found { print $1; found = 1 }')"
    if [ -n "$base" ]; then
      how='the template commit this repository was made from'
      break
    fi
  done
fi
unrelated=''
if [ -z "$base" ]; then
  # NOTHING IN COMMON THAT CAN BE FOUND: a history that was rewritten, or a
  # repository that was never a copy. Merged against nothing at all, every
  # file that differs is a file both sides changed, so yours are all kept and
  # only the template's new files come in.
  base="$(git commit-tree "$(git hash-object -t tree /dev/null)" -m 'nothing in common' < /dev/null)"
  how='nothing: no commit of the template matches where this repository began'
  unrelated=1
fi

if [ "$(git rev-parse "$base^{tree}")" = "$(git rev-parse "$theirs^{tree}")" ]; then
  nothing "$upstream has nothing this repository has not taken (${theirs:0:7})"
fi

# THE MERGE, in memory: no working tree is touched, so a run that stops half
# way leaves nothing behind it.
set +e
merged="$(git merge-tree --write-tree --name-only --no-messages --merge-base="$base" HEAD "$theirs")"
status=$?
set -e
if [ "$status" -gt 1 ]; then
  echo "::error::git could not merge $upstream into this repository (merge-tree exited $status)" >&2
  exit 1
fi
tree="$(printf '%s\n' "$merged" | sed -n '1p')"
both="$(printf '%s\n' "$merged" | sed '1d' | sed '/^$/,$d' | sort -u)"

export GIT_INDEX_FILE="$work/index"
git read-tree "$tree"

# As this repository has it: the file as it is here, or gone if it is not here.
ours() {
  local entry mode kind blob
  entry="$(git ls-tree HEAD -- "$1")"
  if [ -n "$entry" ]; then
    read -r mode kind blob _ <<< "$entry"
    git update-index --add --cacheinfo "$mode,$blob,$1"
  else
    git update-index --force-remove -- "$1"
  fi
}
blob() { git rev-parse --quiet --verify "$1:$2" 2>/dev/null || true; }

kept=''
while IFS= read -r path; do
  [ -n "$path" ] || continue
  ours "$path"
  case "$path" in "$workflows"/*) ;; *) kept="$kept$path"$'\n' ;; esac
done <<< "$both"

# Every workflow, as this repository has it.
while IFS= read -r path; do
  [ -n "$path" ] || continue
  ours "$path"
done <<< "$( { git ls-files -- "$workflows"; git ls-tree -r --name-only HEAD -- "$workflows"; } | sort -u)"

# And which of them the template changed since, for the list.
byhand=''
gone=''
while IFS= read -r path; do
  [ -n "$path" ] || continue
  t="$(blob "$theirs" "$path")"
  if [ "$t" != "$(blob "$base" "$path")" ] && [ "$t" != "$(blob HEAD "$path")" ]; then
    if [ -n "$t" ]; then byhand="$byhand$path"$'\n'; else gone="$gone$path"$'\n'; fi
  fi
done <<< "$( { git ls-tree -r --name-only "$theirs" -- "$workflows"; git ls-tree -r --name-only "$base" -- "$workflows"; } | sort -u)"

# What a conflict leaves beside a file (`name~HEAD` and the like) is in
# neither repository, and is not wanted in this one.
known="$( { git ls-tree -r --name-only HEAD; git ls-tree -r --name-only "$theirs"; } | sort -u)"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  git update-index --force-remove -- "$path"
done <<< "$(comm -23 <(git ls-files | sort -u) <(printf '%s\n' "$known"))"

taken="$(git diff-index --cached --name-status HEAD -- . ":(exclude)$record")"
if [ -z "$taken" ] && [ -z "$kept" ] && [ -z "$byhand" ] && [ -z "$gone" ]; then
  nothing "$upstream moved to ${theirs:0:7}, and nothing in that is new to this repository"
fi

note="$(printf '%s\n' \
  "# The commit of $upstream this repository last took." \
  '# Written by .github/scripts/sync-template.sh; the next sync merges from here.' \
  "$theirs" | git hash-object -w --stdin)"
git update-index --add --cacheinfo "100644,$note,$record"
result="$(git write-tree)"
unset GIT_INDEX_FILE

title="Sync from $upstream at ${theirs:0:7}"
: "${GIT_AUTHOR_NAME:=github-actions[bot]}" "${GIT_AUTHOR_EMAIL:=41898282+github-actions[bot]@users.noreply.github.com}"
: "${GIT_COMMITTER_NAME:=$GIT_AUTHOR_NAME}" "${GIT_COMMITTER_EMAIL:=$GIT_AUTHOR_EMAIL}"
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
commit="$(git commit-tree "$result" -p HEAD -m "$title" -m "Merged three ways from $upstream, from where this repository last stood to $theirs. The pull request says what was taken and what was left.")"

list() { printf '%s' "$1" | sed '/^$/d' | while IFS= read -r path; do printf -- '- [`%s`](https://github.com/%s/blob/%s/%s)\n' "$path" "$upstream" "$theirs" "$path"; done; }
{
  echo "What [$upstream](https://github.com/$upstream) has that this repository did not, up to \`${theirs:0:7}\`. Merged three ways, starting from $how."
  echo
  echo '**Read the diff before merging.** Most of what a templates repository holds is instructions an agent follows, and this is the review they get.'
  if [ -n "$unrelated" ]; then
    echo
    echo 'Because nothing in common was found, every file that differs was treated as changed on both sides: yours are all kept and listed below, and only files this repository did not have were taken. After this is merged the next sync starts from here and merges properly.'
  fi
  echo
  echo '### Taken'
  echo
  if [ -n "$taken" ]; then
    echo '```'
    printf '%s\n' "$taken"
    echo '```'
  else
    echo 'Nothing. This pull request only moves the note of where this repository stands, so the lists below are not made again next time.'
  fi
  if [ -n "$kept" ]; then
    echo
    echo '### Left as yours'
    echo
    echo 'Changed in the template and here, on the same lines. Yours is kept as it is; each link is the template'"'"'s version, to take from by hand.'
    echo
    list "$kept"
  fi
  if [ -n "$byhand$gone" ]; then
    echo
    echo '### Workflows, to change by hand'
    echo
    echo 'The template changed these. A workflow is not allowed to push a change to a workflow with the token it runs on, so none is in this pull request.'
    echo
    list "$byhand"
    printf '%s' "$gone" | sed '/^$/d' | while IFS= read -r path; do printf -- '- `%s`, which the template no longer has\n' "$path"; done
  fi
  if [ -z "$unrelated" ]; then
    echo
    echo '### In the template since'
    echo
    echo '```'
    git log --format='%h %s' --max-count=40 "$base..$theirs"
    echo '```'
  fi
} > "$body"

emit changed true
emit commit "$commit"
emit title "$title"
emit body "$body"

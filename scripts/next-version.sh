#!/usr/bin/env bash
# Compute the next release tag from the conventional commits since the last tag.
#
# Prints the tag to stdout (and appends "tag=<value>" to $GITHUB_OUTPUT when set).
# Prints nothing and writes an empty value when the range warrants no release.
#
# Bump mapping, from each commit's SUBJECT line:
#   <type>!: / BREAKING CHANGE: in the body    -> major
#   feat:                                      -> minor
#   fix: perf: build: refactor: chore(deps):   -> patch
#   docs: test: chore: ci: style:              -> none
# The highest bump in the range wins. "[skip release]" on the head commit -- in its
# subject, or alone on its own line -- forces none.
#
# Only the subject carries the type, per the conventional-commits spec. Bodies are
# scanned solely for BREAKING CHANGE: and [skip release] -- a body that merely
# discusses "feat:" or "fix:" must not trigger a release, which is why commits are
# parsed as NUL-separated records rather than as a flat stream of lines.
#
# On a prerelease base (vX.Y.Z-rcN or vX.Y.Z-rc.N) any non-none bump only advances
# the rc counter and normalises it to the dotted form: the semver triple is frozen
# until GA is tagged by hand. The dot matters -- "rcN" is a single alphanumeric
# identifier compared as a string, so rc10 would sort BELOW rc9, whereas the dotted
# form is a numeric identifier and increments correctly without bound.
#
# Env overrides, used by next-version_test.sh:
#   LATEST_TAG           base tag, instead of `git describe`. Unless
#                        COMMIT_MESSAGES_FILE is also set, the tag must exist:
#                        the commit range is still `$LATEST_TAG..HEAD`.
#   COMMIT_MESSAGES_FILE file of NUL-separated commit messages, instead of `git log`
#                        (as produced by `git log -z --format=%B`)
set -euo pipefail

die() {
  printf 'next-version: %s\n' "$1" >&2
  exit 1
}

# Rank so the highest bump across the range wins regardless of commit order.
rank() {
  case "$1" in
    none) echo 0 ;;
    patch) echo 1 ;;
    minor) echo 2 ;;
    major) echo 3 ;;
    *) die "unknown bump level: $1" ;;
  esac
}

# Bump level for one commit's subject line, ignoring any body.
subject_bump() {
  local subject="$1" type scope breaking

  # ^type(scope)?!?: subject
  if ! printf '%s' "$subject" | grep -qE '^[a-z]+(\([^)]*\))?!?:[[:space:]]'; then
    printf 'none\n'
    return 0
  fi

  type="$(printf '%s' "$subject" | sed -E 's/^([a-z]+).*/\1/')"
  scope="$(printf '%s' "$subject" | sed -nE 's/^[a-z]+\(([^)]*)\).*/\1/p')"
  breaking="$(printf '%s' "$subject" | sed -nE 's/^[a-z]+(\([^)]*\))?(!):.*/\2/p')"

  if [ -n "$breaking" ]; then
    printf 'major\n'
    return 0
  fi

  case "$type" in
    feat) printf 'minor\n' ;;
    fix | perf | build | refactor) printf 'patch\n' ;;
    # A dependency bump changes runtime behaviour and must ship; a bare chore:
    # (tidying, metadata, CI) must not.
    chore)
      if [ "$scope" = "deps" ]; then printf 'patch\n'; else printf 'none\n'; fi
      ;;
    *) printf 'none\n' ;;
  esac
}

latest="${LATEST_TAG:-}"
if [ -z "$latest" ]; then
  # Nearest tag by commit topology. Deliberately NOT `git tag --sort=-v:refname`:
  # git's version sort mis-orders prerelease suffixes unless versionsort.suffix is
  # configured, and this repo's rc tags are exactly that case.
  latest="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
  [ -n "$latest" ] || die "no v* tag reachable from HEAD (were tags fetched? needs fetch-depth: 0)"
fi

if [ -n "${COMMIT_MESSAGES_FILE:-}" ]; then
  records="$COMMIT_MESSAGES_FILE"
else
  records="$(mktemp)"
  trap 'rm -f "$records"' EXIT
  # `-z` NUL-TERMINATES each commit. `--format=%B%x00` looks equivalent but is not:
  # git joins entries with a newline, so every record after the first would begin
  # with "\n" and its subject line would read as empty -- silently classifying only
  # the newest commit in the range.
  git log -z --format=%B "${latest}..HEAD" >"$records"
fi

bump=none
skip=0
# Records arrive newest-first, so index 0 is the commit a release would be cut at.
index=0
# read -d '' consumes the NUL-separated records git log emits.
while IFS= read -r -d '' record; do
  # First non-blank line, so a stray leading newline cannot blank out the subject.
  subject_line="$(printf '%s' "$record" | sed -n '/./{p;q;}')"

  # Honour [skip release] only on the HEAD commit -- the one a release would be cut
  # at -- and only in its subject or alone on a line of its own.
  #
  # Head-only matters: skipping does not push a tag, so the base tag does not
  # advance and a marked commit stays inside `$latest..HEAD` on every later run.
  # Matching it anywhere in the range therefore latched the whole release line off
  # permanently after one marked merge. Restricting to prose-safe positions matters
  # for the same reason the type is read only from the subject: a message that
  # merely mentions the marker must not suppress a real release.
  if [ "$index" -eq 0 ] && {
    printf '%s' "$subject_line" | grep -qF '[skip release]' ||
      printf '%s' "$record" | grep -qE '^[[:space:]]*\[skip release\][[:space:]]*$'
  }; then
    skip=1
  fi

  this="$(subject_bump "$subject_line")"

  # A BREAKING CHANGE: footer promotes the commit regardless of its type, but only
  # if the commit is conventional at all -- otherwise a quoted footer in a merge
  # blurb would escalate the whole range.
  #
  # Per Conventional Commits this is a FOOTER, so only the last paragraph counts.
  # Scanning every line let a fix: whose body quotes the policy (which AGENTS.md
  # now spells out verbatim, so it invites pasting) silently cut a major release.
  if [ "$this" != none ]; then
    footer="$(printf '%s\n' "$record" | awk 'BEGIN { RS = "" } END { print }')"
    if printf '%s' "$footer" | grep -qE '^BREAKING[ -]CHANGE:'; then
      this=major
    fi
  fi

  if [ "$(rank "$this")" -gt "$(rank "$bump")" ]; then
    bump="$this"
  fi

  index=$((index + 1))
done <"$records"

emit() {
  local tag="${1:-}"
  [ -n "$tag" ] && printf '%s\n' "$tag"
  [ -n "${GITHUB_OUTPUT:-}" ] && printf 'tag=%s\n' "$tag" >>"$GITHUB_OUTPUT"
  return 0
}

if [ "$skip" -eq 1 ]; then
  printf 'next-version: [skip release] found in the range; no tag.\n' >&2
  emit ""
  exit 0
fi
if [ "$bump" = none ]; then
  printf 'next-version: no release-worthy commits since %s; no tag.\n' "$latest" >&2
  emit ""
  exit 0
fi

printf '%s' "$latest" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-.+)?$' \
  || die "base tag '$latest' is not a vX.Y.Z[-prerelease] version"

core="$(printf '%s' "$latest" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
pre="$(printf '%s' "$latest" | sed -nE 's/^v[0-9]+\.[0-9]+\.[0-9]+-(.+)$/\1/p')"
major="${core%%.*}"
patch="${core##*.}"
minor="${core#*.}"
minor="${minor%%.*}"

if [ -n "$pre" ]; then
  # Prerelease base: advance the counter only, and normalise rcN -> rc.N.
  n="$(printf '%s' "$pre" | sed -nE 's/^rc\.?([0-9]+)$/\1/p')"
  [ -n "$n" ] || die "base tag '$latest' has an unrecognised prerelease suffix '$pre'; expected rcN or rc.N. Refusing to guess -- tag GA by hand first."
  next="v${core}-rc.$((n + 1))"
  printf 'next-version: %s bump on prerelease base %s -> advancing rc counter.\n' "$bump" "$latest" >&2
else
  case "$bump" in
    major) next="v$((major + 1)).0.0" ;;
    minor) next="v${major}.$((minor + 1)).0" ;;
    patch) next="v${major}.${minor}.$((patch + 1))" ;;
  esac
  printf 'next-version: %s bump on release base %s.\n' "$bump" "$latest" >&2
fi

printf 'next-version: %s -> %s\n' "$latest" "$next" >&2
emit "$next"

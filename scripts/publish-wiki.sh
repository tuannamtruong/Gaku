#!/usr/bin/env bash
#
# Build the GitHub wiki tree from docs/.
#
#   scripts/publish-wiki.sh <wiki-checkout-dir>
#
# Copies the verbatim pages in docs/wiki/ (Home, _Sidebar, _Footer) plus every
# entry in docs/wiki/manifest.txt into the given directory, renaming each source
# file to its wiki page name. Markdown files already in the target that the
# manifest no longer produces are deleted, so removing a manifest line removes
# the page.
#
# Does not commit or push — that is the caller's job. Run it against a scratch
# directory to preview what would be published.

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly MANIFEST="$REPO_ROOT/docs/wiki/manifest.txt"
readonly VERBATIM=(Home.md _Sidebar.md _Footer.md)

warnings=0

warn() {
  printf 'warning: %s\n' "$1" >&2
  warnings=$((warnings + 1))
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

# GitHub renders a wiki page from a flat namespace, so a link written for the
# repo view (../foo.md, docs/bar.md) resolves to nothing once published. What
# survives: absolute URLs, same-page anchors, [[WikiLinks]], and a bare page name
# such as (Database-Schema). The pattern below flags the rest — a target holding
# a path separator or a .md extension.
check_relative_links() {
  local file="$1" page="$2" hits
  hits="$(grep -nP '\]\((?!https?://|#|mailto:)(?=[^)]*(?:/|\.md))[^)]*\)' "$file" || true)"
  if [[ -n "$hits" ]]; then
    warn "$page has links that will not resolve in the wiki:"
    sed 's/^/    /' >&2 <<<"$hits"
  fi
}

main() {
  local target="${1:-}"
  [[ -n "$target" ]] || die "usage: $0 <wiki-checkout-dir>"
  [[ -f "$MANIFEST" ]] || die "manifest not found: $MANIFEST"

  # Created rather than required, so previewing into a scratch path is a
  # one-liner. The workflow always passes a real wiki clone.
  mkdir -p "$target"

  # Clear previously published pages. Anything not regenerated below is gone,
  # which is how page deletion propagates.
  find "$target" -maxdepth 1 -name '*.md' -delete

  local page
  for page in "${VERBATIM[@]}"; do
    local src="$REPO_ROOT/docs/wiki/$page"
    [[ -f "$src" ]] || die "missing verbatim page: docs/wiki/$page"
    cp "$src" "$target/$page"
    check_relative_links "$target/$page" "$page"
    printf 'docs/wiki/%-32s -> %s\n' "$page" "$page"
  done

  local line source name published=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ -n "${line// /}" ]] || continue

    IFS='|' read -r source name <<<"$line"
    # shellcheck disable=SC2001
    source="$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"$source")"
    name="$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"$name")"
    [[ -n "$source" && -n "$name" ]] || die "malformed manifest line: $line"

    local src="$REPO_ROOT/$source"
    [[ -f "$src" ]] || die "manifest lists a file that does not exist: $source"

    if [[ ! -s "$src" ]]; then
      warn "$source is empty — skipping page $name"
      continue
    fi

    cp "$src" "$target/$name.md"
    check_relative_links "$target/$name.md" "$name"
    printf '%-36s -> %s\n' "$source" "$name"
    published=$((published + 1))
  done <"$MANIFEST"

  printf '\n%d pages published, %d warning%s\n' \
    "$((published + ${#VERBATIM[@]}))" "$warnings" "$([[ $warnings -eq 1 ]] || echo s)"
}

main "$@"

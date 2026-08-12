#!/usr/bin/env bash
#
# migrate_to_v4.sh - safe, purely-textual codemods to help upgrade an app
# from router_builder v3 to v4.
#
# v4 splits the code generator out of `router_builder` into a separate
# build-time package, `router_builder_generator`, so that analyzer/build/
# dart_style no longer sit in an app's production dependency graph and can no
# longer cap the versions the app is allowed to resolve.
#
# Your Dart source does NOT change: the import stays
# `package:router_builder/router_builder.dart`. The migration is a pubspec
# change plus, if you have one, a build.yaml builder-key rename.
#
# Run it from your app's root, ideally on a clean git tree so you can review
# the diff. It is a DRY-RUN by default: it prints what would change and edits
# nothing. Re-run with --write to apply.
#
# Usage:
#   tool/migrate_to_v4.sh [--write] [path ...]
#
#   path        one or more files/dirs to scan (default: current directory)
#   -w, --write apply changes in place (default: dry-run preview)
#   -h, --help  show this help and exit
#
# What it rewrites (only the reliable, mechanical changes):
#   - pubspec.yaml: `router_builder:` hosted constraint -> ^4.0.0
#   - pubspec.yaml: adds `router_builder_generator: ^4.0.0` to dev_dependencies
#                   (inserted first in the block; re-sort by hand if you enable
#                    the `sort_pub_dependencies` lint)
#   - build.yaml:   builder key `router_builder:generate_route_info_helper`
#                   -> `router_builder_generator:generate_route_info_helper`
#
# What it deliberately does NOT touch:
#   - path/git `router_builder` dependencies (your override is intentional)
#   - anything in your Dart sources - v4 changes no runtime API
#
# After running, regenerate: `dart run build_runner build`
#
# Idempotent: running it again on already-migrated code changes nothing.

set -euo pipefail

usage() {
  sed -n '3,40p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'
}

write=0
paths=()

while [ $# -gt 0 ]; do
  case "$1" in
    -w|--write) write=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done ;;
    -*) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    *) paths+=("$1"); shift ;;
  esac
done

if [ ${#paths[@]} -eq 0 ]; then
  paths=(".")
fi

command -v perl >/dev/null 2>&1 || {
  echo "error: this script needs perl (preinstalled on macOS and most Linux)." >&2
  exit 1
}

# pubspec.yaml codemod. Applied to the whole file at once.
read -r -d '' pubspec_codemod <<'PERL' || true
# 1. Bump a hosted router_builder constraint to ^4.0.0. The constraint must be
#    non-empty and on the same line: a path/git dependency writes a bare
#    `router_builder:` with the source on following lines, and rewriting that
#    would orphan those lines, so it is left alone.
s{^([ \t]*)router_builder:[ \t]*(['"]?)([^\s'"][^\n'"]*?)\2[ \t]*$}{$1router_builder: ^4.0.0}mg;

# 2. Ensure router_builder_generator is a dev_dependency (idempotent).
unless (/^[ \t]*router_builder_generator[ \t]*:/m) {
  if (/^dev_dependencies:[ \t]*$/m) {
    s{^dev_dependencies:[ \t]*$}{dev_dependencies:\n  router_builder_generator: ^4.0.0}m;
  } else {
    $_ .= "\ndev_dependencies:\n  router_builder_generator: ^4.0.0\n";
  }
}
PERL

# build.yaml codemod: the builder moved packages, so its key changed.
read -r -d '' buildyaml_codemod <<'PERL' || true
s/\brouter_builder:generate_route_info_helper\b/router_builder_generator:generate_route_info_helper/g;
# `- router_builder` under a builders/global_options list refers to the builder
# package; only rewrite when it is qualified with the builder name above.
PERL

changed=0
scanned=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

apply() {
  local file="$1" codemod="$2"
  scanned=$((scanned + 1))
  perl -0777 -pe "$codemod" "$file" > "$tmp"
  if ! cmp -s "$file" "$tmp"; then
    changed=$((changed + 1))
    if [ "$write" -eq 1 ]; then
      cat "$tmp" > "$file"   # truncate-in-place: keeps the file's permissions
      echo "updated: $file"
    else
      echo "would update: $file"
      diff -u "$file" "$tmp" || true
      echo ""
    fi
  fi
}

while IFS= read -r file; do
  apply "$file" "$pubspec_codemod"
done < <(find "${paths[@]}" -type f -name 'pubspec.yaml' \
           ! -path '*/.*' ! -path '*/build/*' 2>/dev/null | sort)

while IFS= read -r file; do
  apply "$file" "$buildyaml_codemod"
done < <(find "${paths[@]}" -type f -name 'build.yaml' \
           ! -path '*/.*' ! -path '*/build/*' 2>/dev/null | sort)

echo ""
if [ "$write" -eq 1 ]; then
  echo "done: $changed of $scanned file(s) updated."
  echo "next: dart run build_runner build"
else
  echo "dry-run: $changed of $scanned file(s) would change."
  echo "re-run with --write to apply (review the diff above first)."
fi

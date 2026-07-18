#!/usr/bin/env bash
#
# migrate_to_v3.sh - safe, purely-textual codemods to help upgrade an app
# from router_builder v2 to v3.
#
# Run it from your app's root, ideally on a clean git tree so you can review
# the diff. It is a DRY-RUN by default: it prints what would change and edits
# nothing. Re-run with --write to apply.
#
# Usage:
#   tool/migrate_to_v3.sh [--write] [path ...]
#
#   path        one or more files/dirs to scan (default: lib)
#   -w, --write apply changes in place (default: dry-run preview)
#   -h, --help  show this help and exit
#
# What it rewrites (only the reliable, mechanical changes):
#   - removes `isIdSlug: true|false` (field/param removed in v3)
#   - MyRoutes        -> Routes
#   - RouteInfoHelper -> RoutesHelper
#   - route_info_helper.dart -> routes.g.dart           (in imports)
#   - deep router_builder imports -> the single barrel:
#       package:router_builder/router_builder.dart
#     (and collapses the duplicate barrel imports that produces)
#
# What it deliberately does NOT touch (needs human judgement - see
# MIGRATION_GUIDE.md, "v2 -> v3 / Manual steps"):
#   - flat behavioral params (isGlobalOnly, mustBeAuthorized, visibleNavBar,
#     isPopupRoute, shouldReplaceAll, isTopLevelOnly, duplicateBehavior,
#     pushGlobally, deepLinkAllowed) -> must move inside `policy: RoutePolicy(...)`
#   - RouterBuilderConfig.setDefaults(named: ...) -> setDefaults(RoutePolicy(...))
#   - RouteArgs subclasses forwarding `super.<flat param>`
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
  paths=("lib")
fi

command -v perl >/dev/null 2>&1 || {
  echo "error: this script needs perl (preinstalled on macOS and most Linux)." >&2
  exit 1
}

# The codemod as a perl program, applied to each file's full contents at once.
read -r -d '' codemod <<'PERL' || true
# 1. remove isIdSlug declarations: own-line, then inline (with trailing comma),
#    then inline as the last argument (leading comma).
s/^[ \t]*isIdSlug[ \t]*:[ \t]*(?:true|false)[ \t]*,?[ \t]*\R//mg;
s/isIdSlug[ \t]*:[ \t]*(?:true|false)[ \t]*,[ \t]*//g;
s/,[ \t]*isIdSlug[ \t]*:[ \t]*(?:true|false)[ \t]*(?=\))//g;
# 2. identifier renames (word-boundaried so RouteInfo itself is untouched)
s/\bRouteInfoHelper\b/RoutesHelper/g;
s/\bMyRoutes\b/Routes/g;
# 3. generated-file import rename
s/route_info_helper\.dart/routes.g.dart/g;
# 4. collapse deep router_builder imports to the public barrel
s{package:router_builder/(?:models/(?:models|route_info|route_args|route_policy|duplicate_route_behavior)|annotations/(?:annotations|route)|deeplink/deep_link_matcher|handlers/deep_link_handler|router_config)\.dart}{package:router_builder/router_builder.dart}g;
# 5. drop duplicate barrel imports produced by step 4 (keep the first)
my $seen = 0;
s{^(import ['"]package:router_builder/router_builder\.dart['"];)[ \t]*\R}{ $seen++ ? "" : "$1\n" }mge;
PERL

changed=0
scanned=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r file; do
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
done < <(find "${paths[@]}" -type f -name '*.dart' \
           ! -name '*.g.dart' ! -path '*/.*' ! -path '*/build/*' 2>/dev/null | sort)

echo ""
if [ "$write" -eq 1 ]; then
  echo "done: $changed of $scanned file(s) updated."
else
  echo "dry-run: $changed of $scanned file(s) would change."
  echo "re-run with --write to apply (review the diff above first)."
fi

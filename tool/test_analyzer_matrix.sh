#!/usr/bin/env bash
#
# Runs the generator suite against BOTH ends of its declared `analyzer` range.
#
# The whole point of router_builder_generator being a pure Dart package is that
# it can resolve analyzer versions a Flutter package cannot (Flutter pins `meta`
# exactly, which caps analyzer below 13.1.0). This script proves the declared
# range is real rather than aspirational — run it before widening that range.
#
# Usage: tool/test_analyzer_matrix.sh
set -euo pipefail

RANGE='>=13.0.0 <15.0.0'
FLOOR='13.0.0'

cd "$(dirname "$0")/../generator"

restore() {
  dart pub add "analyzer:$RANGE" >/dev/null 2>&1 || true
  dart pub upgrade >/dev/null 2>&1 || true
  # `pub add` rewrites the constraint with double quotes; keep the file's style.
  perl -pi -e "s/^  analyzer: \".*\"\$/  analyzer: '\$ENV{RANGE}'/" pubspec.yaml
}
export RANGE
trap restore EXIT

resolved() {
  awk '/^  [a-z_]+:$/{pkg=$1} /^    version:/{gsub(/"/,"",$2); print pkg, $2}' \
    pubspec.lock | grep -E "^(analyzer|build|dart_style):" | tr '\n' ' '
}

echo "==> Ceiling: analyzer $RANGE (newest resolvable)"
dart pub add "analyzer:$RANGE" >/dev/null
dart pub upgrade >/dev/null
echo "    resolved: $(resolved)"
dart analyze
dart test

echo
echo "==> Floor: analyzer $FLOOR"
dart pub add "analyzer:$FLOOR" >/dev/null
echo "    resolved: $(resolved)"
dart analyze
dart test

echo
echo "==> Both ends of 'analyzer $RANGE' pass."

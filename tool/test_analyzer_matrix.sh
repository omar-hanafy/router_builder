#!/usr/bin/env bash
# Run the generator with the lowest and newest compatible dependency sets.
# Usage: tool/test_analyzer_matrix.sh [floor|latest]
set -euo pipefail

case "${1:-all}" in
  floor|latest|all) lane=${1:-all} ;;
  *) echo "Usage: $0 [floor|latest]" >&2; exit 2 ;;
esac

generator_dir=$(cd "$(dirname "$0")/../generator" && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/router-builder-generator.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
rsync -a --exclude='.dart_tool/' --exclude='build/' --exclude='coverage/' \
  --exclude='pubspec.lock' --exclude='pubspec_overrides.yaml' \
  "$generator_dir/" "$scratch/"
cd "$scratch"

resolved_version() {
  awk -v package="$1" '
    $0 == "  " package ":" { found = 1 }
    found && $1 == "version:" { gsub(/"/, "", $2); print $2; exit }
  ' pubspec.lock
}

check_version() {
  local package=$1 expected=$2 actual
  actual=$(resolved_version "$package")
  if [[ $actual != "$expected" && $actual != "$expected".* ]]; then
    echo "Expected $package $expected, resolved $actual" >&2
    exit 1
  fi
  echo "$package $actual"
}

if [[ $lane != latest ]]; then
  echo 'Testing the lowest supported versions'
  dart pub downgrade --no-example
  check_version analyzer 13.0.0
  check_version build 4.0.6
  dart analyze --fatal-infos
  # The downgraded test compiler client expects a retired SDK snapshot.
  # Run the same suites directly on the VM with the supported source compiler.
  dart test --compiler=source
fi

if [[ $lane != floor ]]; then
  echo 'Testing the newest compatible versions'
  dart pub upgrade --no-example
  check_version analyzer 14
  check_version build 5
  dart analyze --fatal-infos
  dart test
fi

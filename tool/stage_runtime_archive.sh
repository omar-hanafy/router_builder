#!/usr/bin/env bash
# Validate the runtime release archive and resolve its bundled Flutter example.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <git-revision> <new-output.tar.gz>" >&2
  exit 2
fi

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
revision=$(git -C "$repo" rev-parse --verify --end-of-options "$1^{commit}")
output=$2
if [[ -e "$output" || -L "$output" ]]; then
  echo "Archive destination already exists: $output" >&2
  exit 1
fi

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/source" "$scratch/unpacked"
git -C "$repo" archive "$revision" -- . ':(exclude)generator' \
  ':(exclude,glob)**/pubspec_overrides.yaml' | tar -xf - -C "$scratch/source"

archive="$scratch/router_builder.tar.gz"
(
  cd "$scratch/source"
  dart pub publish --dry-run
  dart pub publish --to-archive="$archive"
)

tar -tzf "$archive" > "$scratch/contents"
if grep -E '^(generator(/|$)|(.*/)?pubspec_overrides\.yaml$)' "$scratch/contents"; then
  echo "Runtime archive contains generator sources or a local dependency override." >&2
  exit 1
fi
tar -xzf "$archive" -C "$scratch/unpacked"
for file in pubspec.yaml lib/router_builder.dart example/pubspec.yaml example/lib/main.dart example/lib/routes.g.dart; do
  if [[ ! -f "$scratch/unpacked/$file" ]]; then
    echo "Runtime archive is missing $file." >&2
    exit 1
  fi
done
(cd "$scratch/unpacked/example" && flutter pub get)

mv -n "$archive" "$output"
if [[ -e "$archive" ]]; then
  echo "Archive destination already exists: $output" >&2
  exit 1
fi
echo "Created $output from $revision."

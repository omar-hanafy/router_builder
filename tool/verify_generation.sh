#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
example="$repo/example"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Preserve the example's relative package paths in a disposable checkout.
ln -s "$repo/pubspec.yaml" "$repo/lib" "$repo/generator" "$scratch/"
mkdir "$scratch/example"
cd "$scratch/example"
cp "$example"/*.yaml .
cp -R "$example/lib" "$example/test" .
rm lib/routes.g.dart

flutter pub get
dart run build_runner build
if [[ ! -s lib/routes.g.dart ]]; then
  echo 'Expected build_runner to generate lib/routes.g.dart' >&2
  exit 1
fi
# The SDK formatter and the resolved dart_style formatter can differ.
dart format lib/routes.g.dart
diff -u "$example/lib/routes.g.dart" lib/routes.g.dart
flutter analyze --no-pub
flutter test --no-pub

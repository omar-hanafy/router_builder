---
name: migrate-v3-to-v4
description: Use when executing a confirmed router_builder 3.x to 4.x upgrade, or when a build breaks after one with errors like "package:router_builder/builder.dart" not found, a build.yaml key router_builder:generate_route_info_helper that no longer applies, build_runner reporting no builders applied so routes.g.dart stops regenerating, or a pub solve that caps analyzer/build_runner because router_builder is in dependencies. For a version bump where the path is still unclear, start with upgrade-router-builder.
---

# Migrate router_builder v3 -> v4

Supported: any 3.x -> 4.x. For 2.x sources, run `migrate-v2-to-v3` first.

**This migration changes no Dart code.** No runtime API, annotation, or import
changed. v4 moves the code generator out of `router_builder` into a new
build-time package, `router_builder_generator`. It is a pubspec migration.

Why it exists, and the full old -> new mapping:
[references/v4-package-split.md](references/v4-package-split.md).

## Preconditions

- Clean git tree (the codemod edits in place; the diff must be reviewable).
  Uncommitted work: stop and ask, or have the user stash/commit first.
- Confirm the installed version from `pubspec.lock`, not the pubspec
  constraint. If the lockfile already says 4.x AND
  `grep -rn "router_builder_generator" pubspec.yaml` hits, the project is
  migrated - verify with `dart analyze` and stop.
- **Check the Flutter SDK floor before touching anything.** v4's generator
  needs `analyzer >=13.0.0`, which needs `meta ^1.18.0`, which means Flutter
  3.44 or newer. Run `flutter --version`. On an older SDK the solve will fail
  with a `meta` conflict; the fix is upgrading Flutter, not editing
  constraints. If the user cannot upgrade Flutter, stop and tell them to stay
  on 3.x - do not attempt to force it with `dependency_overrides`.

## Step 1: Run the automated codemod

Use the bundled script [scripts/migrate_to_v4.sh](scripts/migrate_to_v4.sh)
(the same file ships in the package repo at `tool/migrate_to_v4.sh`). From the
APP root:

```bash
bash <path-to>/migrate_to_v4.sh          # DRY-RUN: prints a unified diff, edits nothing
bash <path-to>/migrate_to_v4.sh --write  # apply after reviewing the diff
```

It rewrites only the always-safe changes, and is idempotent:

- the hosted `router_builder:` constraint in every `pubspec.yaml` -> `^4.0.0`
- adds `router_builder_generator: ^4.0.0` to `dev_dependencies`
- renames any `build.yaml` builder key
  `router_builder:generate_route_info_helper` ->
  `router_builder_generator:generate_route_info_helper`

It deliberately leaves a `path:`/`git:` `router_builder` dependency alone -
that override belongs to the user.

The inserted `dev_dependencies` entry goes first in the block. If the project
enables the `sort_pub_dependencies` lint, re-sort it by hand.

## Step 2: Resolve and regenerate

```bash
flutter pub get
dart run build_runner build
```

Two things to expect, neither of which is an error:

- **`routes.g.dart` gets a formatting-only diff.** v4 resolves `dart_style`
  3.1.9+, which breaks chained calls differently from 3.1.8. Confirm the diff
  is whitespace only; the route data must be unchanged.
- **The build log now names `router_builder_generator`.** If it still says
  `router_builder:generate_route_info_helper`, a custom `build.yaml` key was
  missed - see Step 3.

If `build_runner` reports that no builders applied and `routes.g.dart` is not
regenerated, the generator is missing from `dev_dependencies`. That is the one
failure mode worth checking first.

## Step 3: Manual changes

For application code there are none. Two cases need a human look:

1. **Custom `build.yaml`.** The codemod handles the standard
   `builders:` key. If the builder was wired through a custom target,
   `global_options`, or an `apply_builders` list, confirm every reference now
   reads `router_builder_generator:generate_route_info_helper`.
2. **A package (not an app) that depends on router_builder.** Put
   `router_builder_generator` in that package's `dev_dependencies`. Leaving it
   in `dependencies` re-creates the transitive constraint v4 exists to remove,
   and its consumers inherit the analyzer cap again.

## Step 4: Verify

```bash
flutter analyze
flutter test
```

Then confirm the split actually took effect - this is the point of the
release:

```bash
grep -E "^  (analyzer|build|dart_style):$" pubspec.lock
```

For an app that only *uses* routes, these should be gone entirely. For an app
that regenerates, they are present via `build_runner` and
`router_builder_generator` as dev dependencies, which is expected and no
longer caps anything transitively.

## Rules

- One hop per commit; run the app's test suite before moving on.
- Never mix the upgrade with feature work or cleanups.
- Do not "fix" a `meta`/`analyzer` solve failure with `dependency_overrides`.
  It means the Flutter SDK is too old; the honest options are upgrading
  Flutter or staying on 3.x.

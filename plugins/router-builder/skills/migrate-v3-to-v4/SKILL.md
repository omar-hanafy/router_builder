---
name: migrate-v3-to-v4
description: Use when executing a confirmed router_builder 3.x to 4.x upgrade, or when a build breaks after one with errors like "package:router_builder/builder.dart" not found, a build.yaml key router_builder:generate_route_info_helper that no longer applies, build_runner reporting no builders applied so routes.g.dart stops regenerating, or a pub solve that caps analyzer/build_runner because router_builder is in dependencies. For a version bump where the path is still unclear, start with upgrade-router-builder.
---

# Migrate router_builder v3 -> v4

Supported: any 3.x -> 4.x. For 2.x sources, run `migrate-v2-to-v3` first.

Route declarations still use `package:router_builder/router_builder.dart`.
The generator moves to `router_builder_generator`. Custom builders that import
or export the old builder library need a Dart URI migration as well as the
dependency and builder configuration changes.

Why it exists, and the full old -> new mapping:
[references/v4-package-split.md](references/v4-package-split.md).

## Preconditions

- Clean git tree (the codemod edits in place; the diff must be reviewable).
  Uncommitted work: stop and ask, or have the user stash/commit first.
- Confirm the installed runtime and generator versions in `pubspec.lock`.
  For a hosted upgrade, confirm that both chosen versions are available.
- Check `flutter --version` against the generator's Dart SDK floor and
  analyze the solver's explanation for incompatible dependency constraints.
  Applications that ship pregenerated routes can use the runtime alone.

## Step 1: Run the automated codemod

Use the bundled script [scripts/migrate_to_v4.sh](scripts/migrate_to_v4.sh)
(the same file ships in the package repo at `tool/migrate_to_v4.sh`). From the
APP root:

```bash
bash /path/to/migrate_to_v4.sh          # DRY-RUN: prints a unified diff, edits nothing
bash /path/to/migrate_to_v4.sh --write  # apply after reviewing the diff
```

The script uses Ruby's standard YAML library. It updates hosted v3 runtime
constraints, adds the generator for packages that declare `build_runner`,
and updates recognized builder keys and import URIs in that package's `build.yaml`. Review its
manual-edit messages for custom constraints, nonstandard YAML, path or Git
sources, and dependency overrides.

## Step 2: Resolve and update custom Dart builders

```bash
flutter pub get
dart run router_builder_generator:migrate_builder_imports
dart run router_builder_generator:migrate_builder_imports --write
```

The first migration command previews file locations. The second changes Dart
imports and exports of `package:router_builder/builder.dart` to
`package:router_builder_generator/builder.dart`, including conditional URIs.
Prefixes, import combinators and comments stay in place. The separate
`dart fix` element transforms cover unprefixed uses. They can leave a prefixed
factory reference or re-export unresolved, so use the directive migration first.
The factory `generateRouteInfoHelperBuilder` and exception `RouterBuilderError`
retain their names. Application imports of the runtime barrel stay as they are.

## Step 3: Review custom wiring and regenerate

- In custom `build.yaml` files check references to
  `router_builder_generator:generate_route_info_helper` and any explicit
  builder import URI. Review wrappers and their builder lists.
- Applications and packages that generate routes during development use a
  generator dev dependency. A published builder that imports or exports the
  generator in its own `lib/` needs it in regular `dependencies`.
- Run `dart run build_runner build`. Review `lib/routes.g.dart`. The resolved
  formatter version may change line breaks.

## Step 4: Verify

```bash
flutter analyze
flutter test
```

Run `flutter pub deps --style=compact` and inspect the dependencies listed
for `router_builder`. Its direct runtime dependencies are `flutter`,
`dart_helper_utils` and `equatable`. An app's other packages and dev tools
can bring analyzer and build packages into the same lockfile.

## Rules

- One hop per commit; run the app's test suite before moving on.
- Never mix the upgrade with feature work or cleanups.
- Resolve incompatible SDK and package constraints using the solver explanation.
  Keep any intentional local overrides explicit.

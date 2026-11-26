# router_builder - maintainer guide for coding agents

**Two packages in one repository** share a version and publish separately.

- `router_builder` (repo root) - the Flutter runtime. Barrel at
  `lib/router_builder.dart`. Depends ONLY on `flutter`, `dart_helper_utils`,
  `equatable`.
- `router_builder_generator` (`generator/`) - the build-time builder, entry at
  `generator/lib/builder.dart`. **Pure Dart, no `flutter` dependency.**

Consumers get typed routes + deep-link matching from `@RT()` annotations,
putting the runtime in `dependencies` and the generator in `dev_dependencies`.

Keep independent resolutions and lockfiles. Putting these packages in a Pub
workspace would constrain the generator's analyzer matrix to dependencies
compatible with the installed Flutter SDK.

## Validation commands (run before claiming any change done)

```bash
flutter test                                 # runtime tests (repo root)
dart analyze                                 # public_member_api_docs is an ERROR here
dart format --output=none --set-exit-if-changed .
(cd generator && dart analyze && dart test)  # generator tests (plain dart test; pure Dart package)
tool/test_analyzer_matrix.sh                 # generator at BOTH ends of its analyzer range
dart tool/validate_plugin.dart               # AI plugin tree: versions, paths, parity
```

For releases run `dart pub publish --dry-run` in `generator/` and
`tool/stage_runtime_archive.sh HEAD /tmp/router_builder.tar.gz` for the
runtime, choosing a new archive path. The helper validates the release
revision without nesting the generator and resolves the archived example.
Inspect both file lists. Publish the runtime from that verified archive.

## Boundaries

- Never hand-edit `*.g.dart`. Regenerate the example's file with
  `cd example && dart run build_runner build`.
- **Never add `analyzer`, `build`, `dart_style`, `glob`, or `source_gen` to the
  root pubspec.** They belong to `generator/` alone. Putting them back in the
  runtime's `dependencies` re-creates the exact defect v4 removed: pub must
  resolve them for every consumer, capping the app's build chain and leaking
  that cap transitively to anything depending on router_builder. CI asserts
  their absence from `pubspec.lock`.
- **Keep `generator/` free of Flutter dependencies**, including dev. The Dart
  generator must be able to resolve its full declared range independently. Generator tests use stubbed package sources
  (`generator/test/_support.dart`) instead of real Flutter; real-Flutter
  coverage lives in `example/`.
- Public API is ONLY what the two entrypoints export: `lib/router_builder.dart`
  for the runtime, `generator/lib/builder.dart` for the builder. New runtime
  files go under `lib/src/`; new generator files under `generator/lib/src/`.
- `docs/superpowers/` holds design history; do not treat it as current spec
  where it conflicts with `lib/src/`.

## AI assistant plugin (plugins/router-builder)

- One canonical plugin serves Claude Code (`.claude-plugin/plugin.json`) and
  Codex (`.codex-plugin/plugin.json`); marketplaces live at
  `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`.
- Versions must stay in sync: pubspec.yaml == generator/pubspec.yaml == both
  plugin.json == the Claude marketplace entry.
  `dart tool/validate_plugin.dart` enforces this, plus skill frontmatter, link
  integrity, and codemod parity.
- Every `migrate-vN-1-to-vN` skill bundles a copy of its codemod under
  `scripts/`, which must remain byte-identical to the canonical `tool/` copy;
  edit the tool/ copy and re-copy. The validator checks every pair listed in
  its `codemods` table - add the new pair when cutting a major.
- Skill reference files state package semantics as fact; verify any edit
  against `lib/src/` (and the published v2 archive for migration claims)
  before changing them.
- The whole plugin tree ships from git only. `.pubignore` excludes `plugins/`,
  `AGENTS.md`, `CLAUDE.md`; never let a pub.dev archive carry a partial
  plugin.
- `claude plugin validate . --strict` and
  `claude plugin validate ./plugins/router-builder --strict` must pass when
  the claude CLI is available.

## Breaking-release rule (every future major)

A breaking release is not done until it ships, together:
1. `tool/migrate_to_vN.sh` codemod (dry-run by default, mechanical edits only).
2. A `vN-1 -> vN` section in MIGRATION_GUIDE.md (template at its bottom).
3. A new `migrate-vN-1-to-vN` skill in the plugin (mirror the v2-to-v3 one:
   SKILL.md + references API map + bundled codemod copy).
4. An updated routing table in the `upgrade-router-builder` skill.
5. Synced version bumps everywhere the validator checks.

## Recurring maintenance beat: analyzer constraint

Consumer solve conflicts around `analyzer` were this package's most frequent
issue for three majors (2.0.3, 2.0.4, 3.0.1 all shipped only to relax ranges).
v4 removed the cause: the constraint now lives in `router_builder_generator`,
a `dev_dependency`, and dev dependencies are not transitive. A stale bound
there inconveniences someone regenerating; it can no longer block an app's
production graph or leak to downstream packages.

The rule for widening still holds, and is now actually testable:

- Widen the upper bound only when a resolvable dependency set reaches the new
  major (`build`/`dart_style` must support it first) AND
  `tool/test_analyzer_matrix.sh` passes at both ends. Never widen
  speculatively - pana's "does not support latest analyzer" hint alone is not
  evidence. Published v3.1.0 constrained analyzer to `>=9.0.0 <13.0.0`.
- Before raising a lower bound, resolve a real consuming Flutter app with the
  new dependency graph. Document any increase in the minimum supported Dart
  or Flutter version. Flutter 3.44 pinned `meta` to 1.18.0 and relies on the
  generator's analyzer 13.0.0 floor.

## Releasing

Keep the generator and runtime changelogs aligned with their manifests.
Publish the generator first. Before publishing the runtime, resolve the
example from the staged runtime archive against the matching hosted generator.
The local `example/pubspec_overrides.yaml` is for developing both packages
together.

Use annotated `router_builder-vX.Y.Z` tags for the runtime and
`router_builder_generator-vX.Y.Z` tags for the generator. Tag the reviewed
merge on `main` and keep every release tag immutable. A generator release
does not authorize a runtime tag or upload.

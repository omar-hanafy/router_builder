# router_builder - maintainer guide for coding agents

**Two published packages in one repo**, released in lockstep (same version):

- `router_builder` (repo root) - the Flutter runtime. Barrel at
  `lib/router_builder.dart`. Depends ONLY on `flutter`, `dart_helper_utils`,
  `equatable`.
- `router_builder_generator` (`generator/`) - the build-time builder, entry at
  `generator/lib/builder.dart`. **Pure Dart, no `flutter` dependency.**

Consumers get typed routes + deep-link matching from `@RT()` annotations,
putting the runtime in `dependencies` and the generator in `dev_dependencies`.

Each package has its own independent resolution and lockfile. This is
deliberate and is NOT a Pub workspace: workspace members share one resolution,
which would drag Flutter's exact `meta` pin into the generator and cap
`analyzer` below 13.1.0 - defeating the entire point of the split.

## Validation commands (run before claiming any change done)

```bash
flutter test                                 # runtime tests (repo root)
dart analyze                                 # public_member_api_docs is an ERROR here
dart format .
(cd generator && dart analyze && dart test)  # generator tests (plain dart test; pure Dart package)
tool/test_analyzer_matrix.sh                 # generator at BOTH ends of its analyzer range
dart tool/validate_plugin.dart               # AI plugin tree: versions, paths, parity
```

For releases add `dart pub publish --dry-run` in **both** package roots and
inspect each file list.

## Boundaries

- Never hand-edit `*.g.dart`. Regenerate the example's file with
  `cd example && dart run build_runner build`.
- **Never add `analyzer`, `build`, `dart_style`, `glob`, or `source_gen` to the
  root pubspec.** They belong to `generator/` alone. Putting them back in the
  runtime's `dependencies` re-creates the exact defect v4 removed: pub must
  resolve them for every consumer, capping the app's build chain and leaking
  that cap transitively to anything depending on router_builder. CI asserts
  their absence from `pubspec.lock`.
- **Never give `generator/` a `flutter` dependency**, including dev. Flutter
  pins `meta` exactly, which caps `analyzer` below 13.1.0 and would make the
  declared range untestable. Generator tests use stubbed package sources
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
  evidence. The v3.1.0 tree carried an untested `analyzer <15.0.0` bound whose
  generator could not compile against analyzer 13 at all; that is the failure
  this rule exists to prevent.
- Raising the FLOOR is the breaking part, because `analyzer >=13.1.0` needs
  `meta ^1.18.3` and the Flutter SDK pins `meta` exactly. Check which Flutter
  release ships the required `meta` before raising it, and treat the resulting
  Flutter floor as a documented breaking change. v4's floor is 13.0.0 (not
  13.3.0) precisely so Flutter 3.44 stable still resolves it.

## Releasing

Branch `main`, tags `vX.Y.Z` (annotated), CHANGELOG entry first (one per
package), then: full validation commands above, dry-run inspection,
`git tag vX.Y.Z && git push origin main vX.Y.Z`, then publish.

**Publish `router_builder_generator` first, `router_builder` second.**
`example/pubspec.yaml` depends on the generator by hosted version so the
example still resolves inside the published router_builder archive; if the
generator is not on pub.dev yet, pana cannot analyze that example. Local
development uses `example/pubspec_overrides.yaml`, which `.pubignore` keeps
out of the archive.

`.pubignore` also excludes `generator/` from the router_builder archive - the
two packages must never ship nested inside one another.

Never reuse or move a published tag.

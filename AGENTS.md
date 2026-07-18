# router_builder - maintainer guide for coding agents

Flutter package publishing a source_gen builder: runtime API in
`lib/router_builder.dart` (barrel), generator behind `lib/builder.dart`.
Consumers get typed routes + deep-link matching from `@RT()` annotations.

## Validation commands (run before claiming any change done)

```bash
flutter test                                 # model/runtime tests
dart test --run-skipped test/generator/      # generator tests (tagged; flutter test skips them by design)
dart analyze                                 # public_member_api_docs is an ERROR here
dart format .
dart tool/validate_plugin.dart               # AI plugin tree: versions, paths, parity
```

For releases add: `dart pub publish --dry-run` and inspect the file list.

## Boundaries

- Never hand-edit `*.g.dart`. Regenerate the example's file with
  `cd example && dart run build_runner build`.
- Public API is ONLY what the two entrypoints export. New runtime files go
  under `lib/src/` and get exported from the barrel; generator-side code must
  never be exported from the runtime barrel (it drags analyzer/build/dart_style
  into consumer apps).
- `docs/superpowers/` holds design history; do not treat it as current spec
  where it conflicts with `lib/src/`.

## AI assistant plugin (plugins/router-builder)

- One canonical plugin serves Claude Code (`.claude-plugin/plugin.json`) and
  Codex (`.codex-plugin/plugin.json`); marketplaces live at
  `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`.
- Versions must stay in sync: pubspec.yaml == both plugin.json == the Claude
  marketplace entry. `dart tool/validate_plugin.dart` enforces this, plus
  skill frontmatter, link integrity, and codemod parity.
- `plugins/router-builder/skills/migrate-v2-to-v3/scripts/migrate_to_v3.sh`
  must remain byte-identical to `tool/migrate_to_v3.sh`; edit the tool/ copy
  and re-copy.
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

Consumer solve conflicts around `analyzer` are this package's most frequent
issue (2.0.3, 2.0.4, 3.0.1 all relaxed ranges). Widen the `analyzer` upper
bound ONLY when a resolvable dependency set actually reaches the new major
(source_gen/build must support it first) AND the full test suite passes
against it; then ship as a patch. Never widen speculatively - pana's
"does not support latest analyzer" hint alone is not evidence.

## Releasing

Branch `main`, tags `vX.Y.Z` (annotated), CHANGELOG entry first, then: full
validation commands above, dry-run inspection, `git tag vX.Y.Z && git push
origin main vX.Y.Z`, `dart pub publish`. Never reuse or move a published tag.

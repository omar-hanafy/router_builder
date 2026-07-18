---
name: migrate-v2-to-v3
description: Use when executing a confirmed router_builder 2.x to 3.x upgrade, or when code shows v2 tells - flat RouteInfo/RouteArgs params like isGlobalOnly/isIdSlug/mustBeAuthorized as constructor args, imports of package:router_builder/models/..., MyRoutes/RouteInfoHelper, a generated route_info_helper.dart, or RouterBuilderConfig.setDefaults with named parameters. For a version bump where the path is still unclear, start with upgrade-router-builder.
---

# Migrate router_builder v2 -> v3

Supported: any 2.x (2.0.0-2.0.4) -> 3.x. For 1.x sources, bump to 2.0.4 first
(deps-only hop; see the `upgrade-router-builder` skill). The full mechanical +
manual mapping is in [references/v2-api-map.md](references/v2-api-map.md).

The core change: all cascading behavior moved into one `RoutePolicy`
(`args.policy` -> `route.policy` -> global defaults). Flat behavioral params
and getters are gone.

## Preconditions

- Clean git tree (the codemod edits in place; the diff must be reviewable).
  Uncommitted work: stop and ask, or have the user stash/commit first.
- Confirm the actual installed version (`pubspec.lock`, not just pubspec; if
  no lockfile exists, run `flutter pub get` once or infer from the pubspec
  constraint plus code tells) and scan for v2 tells:
  `grep -rn "isGlobalOnly\|isIdSlug\|RouteInfoHelper\|MyRoutes\|models/models.dart" lib/`.
  If NONE appear and the lockfile already says 3.x, the project is already
  migrated - verify with `dart analyze` and stop.

## Step 1: Bump the dependency

`router_builder: ^3.0.1` in pubspec.yaml, then `flutter pub get`. Solve
failures around `analyzer`/`build`/`source_gen` at this point are dependency
conflicts, not migration errors - handle via the `debug-generation` skill,
then return here.

## Step 2: Run the automated codemod (mechanical edits only)

Use the bundled script [scripts/migrate_to_v3.sh](scripts/migrate_to_v3.sh)
(same file ships in the package repo at `tool/migrate_to_v3.sh` and inside the
installed package in the pub cache). From the APP root:

```bash
bash <path-to>/migrate_to_v3.sh lib          # DRY-RUN: prints a unified diff, edits nothing
bash <path-to>/migrate_to_v3.sh --write lib  # apply after reviewing the diff
```

It rewrites ONLY the always-safe changes: removes LITERAL `isIdSlug: true` /
`isIdSlug: false` arguments (a computed value like `isIdSlug:
int.tryParse(x) == null` is left for Step 3), `MyRoutes` -> `Routes`,
`RouteInfoHelper` -> `RoutesHelper`, `route_info_helper.dart` ->
`routes.g.dart` in imports, deep `package:router_builder/...` imports -> the
single barrel (deduplicated). It is idempotent. The dry-run diff may include
the stale v2 GENERATED file (`lib/route_info_helper.dart`) - ignore that hunk;
Step 4 deletes the file. Review the rest of the diff WITH the user's
conventions in mind before `--write`.

## Step 3: Manual changes (the code will not compile until done)

Work through references/v2-api-map.md tables in this order:

1. Fold every flat behavioral constructor arg on `RouteInfo`/`RouteArgs` into
   `policy: RoutePolicy(...)` (`isGlobalOnly` becomes `pushGlobally`). When a
   v2 declaration mixed flat args AND a `policy:`, the flat value wins per
   field. Use presets for single-field policies.
2. Fix read sites: drop `?? default` around the now non-null resolved getters;
   rename `isGlobalOnly` reads to `pushGlobally`; collapse OR-folds like
   `(route.isGlobalOnly ?? false) || args.effectivePushGlobally` to
   `args.effectivePushGlobally` (note the semantic delta in the reference).
3. Replace `isIdSlug` logic with value-based detection at the read site or a
   `RouteArgs` subclass field.
4. `RouteArgs` subclasses: forward `super.policy` instead of flat super-params.
5. `RouterBuilderConfig.setDefaults(named: ...)` -> `setDefaults(const
   RoutePolicy(...))`, or introduce `@RTConfig()` + `RoutesHelper.installDefaults()`
   in `main()`. Preserve the app's exact current defaults; do not "improve"
   them mid-migration.
6. Consumer `build.yaml` (if one exists): import
   `package:router_builder/builder.dart`; either adopt the new output
   (`lib/routes.g.dart`) or pin the old names via builder options. If the app
   has no build.yaml, defaults apply automatically.

## Step 4: Regenerate

Delete the stale v2 generated file (`lib/route_info_helper.dart`) unless the
project pinned old names, then:

```bash
dart run build_runner build
```

A leftover v2 generated file is a loud failure signature: it deep-imports
`package:router_builder/models/models.dart`, which no longer exists.

## Step 5: Verify (all gates, not just analyze)

1. `dart analyze` (or `flutter analyze`): remaining errors are almost always
   missed manual folds; the analyzer names them.
2. Diff the new `routes.g.dart` surface against the old helper: same route
   set, same `deepLinkMap` keys. New build FAILURES about deep-link key
   conflicts expose real pre-existing collisions v2 silently swallowed -
   resolve ownership; do not set `fail_on_conflict: false` to keep the old
   silent behavior without the user agreeing to it.
3. AUDIT allowed hosts: v2 matched hosts by substring; v3 is exact-or-suffix.
   Any host that relied on substring matching (partial names, look-alikes)
   stops resolving. Test each real domain the app uses.
4. Run the app's test suite; add a smoke test asserting a few migrated
   policy reads (`route.pushGlobally`, `args.effectiveMustBeAuthorized`)
   match their v2 values.
5. `dart format` the touched files.

## Rollback

The migration is a working-tree-only change plus a dependency bump: `git
checkout` the branch/stash to return to v2. Never leave the tree half-migrated
(mixed flat params + policy code does not compile); if interrupted, either
finish Step 3 or roll back.

## Report to the user

List: codemod diff summary, every manual fold made, behavioral deltas checked
(host matching, OR-folds), conflicts surfaced, and verification results with
command output.

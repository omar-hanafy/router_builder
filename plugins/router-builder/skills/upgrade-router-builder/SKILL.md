---
name: upgrade-router-builder
description: Use when a project wants to update the router_builder package to a newer version and the migration path is unclear - "upgrade router_builder", "move to the latest router_builder", dependency bumps from 1.x, 2.x or 3.x, or deciding whether an upgrade is breaking before touching code. Also use when router_builder is capping an app's analyzer/build_runner/dart_style upgrade.
---

# Upgrade router_builder (version orchestrator)

Determine the installed version, pick the path, delegate the one breaking hop
to its dedicated skill. Never guess the version from imports alone.

## Step 1: Detect the installed and target versions

- Installed: `grep -A2 "router_builder" pubspec.lock` (the lockfile is truth;
  pubspec constraints can be stale).
- Target: latest 4.x unless the user pinned one (`dart pub outdated` shows it).
- Confirm with API tells when the lockfile is missing: a
  `router_builder_generator` dev dependency means 4.x;
  `Routes`/`RoutesHelper`/`routes.g.dart` and `policy: RoutePolicy(...)` with
  the generator still inside `router_builder` mean 3.x;
  `MyRoutes`/`RouteInfoHelper`/`route_info_helper.dart` or flat params
  (`isGlobalOnly:`, `isIdSlug:`) mean 1.x/2.x.
- Check the generator's Dart SDK and analyzer constraints for packages that
  regenerate routes. For instance, Flutter 3.44's `meta` pin permits analyzer
  13.0.0. A package that uses only the runtime or ships pregenerated routes
  can upgrade the runtime independently of those build-tool constraints.

## Step 2: Route by path

| From -> To | Path |
|---|---|
| 4.x -> newer 4.x | Bump constraint (both packages, they release in lockstep), `flutter pub get`, `dart run build_runner build`, `dart analyze`, run tests. |
| 3.x -> 4.x | Use `migrate-v3-to-v4` for the generator dependency and build configuration. Migrate custom builder imports and exports with `dart run router_builder_generator:migrate_builder_imports --write` after its preview, then regenerate. |
| 3.x -> newer 3.x | Bump constraint, `flutter pub get`, `dart run build_runner build`, `dart analyze`, run tests. 3.0.1 only relaxed the analyzer constraint; no code changes. |
| 2.x -> 4.x | Two hops: `migrate-v2-to-v3`, then `migrate-v3-to-v4`. |
| 2.x -> 3.x | BREAKING. Use the `migrate-v2-to-v3` skill (codemod + manual policy folds + regenerate + host audit). |
| 1.x -> 3.x | Two hops: first 1.x -> 2.0.4 (below), then `migrate-v2-to-v3`. |
| 1.x -> 2.x only | Deps-only hop (below). |
| 0.x | Never published to pub.dev; a 0.x source tree predates the unified deep-link system. Treat as legacy: consult the package MIGRATION_GUIDE.md appendix (v0 -> v1 deep-link registry migration), then continue up the chain. |

## "router_builder is blocking my dependency upgrade"

If a solve conflict names `analyzer`, `build`, `build_runner`, or `dart_style`
and `router_builder` appears in the explanation, the project is on 3.x or
earlier, where those were regular `dependencies` of the runtime package and
capped the app's whole build chain. The fix is the 3.x -> 4.x hop, not a
constraint edit or an override: v4 moves the generator into a
`dev_dependency`, which is not transitive. See `migrate-v3-to-v4`.

## The 1.x -> 2.0.4 hop (deps-only, no dedicated skill needed)

2.0.0-2.0.4 updated analyzer/build_runner-era dependencies and merged the
additive 1.2.0 policy system; it removed nothing. Mechanics:

1. Set `router_builder: ^2.0.4`, `flutter pub get`. Resolve any
   analyzer/build_runner solve conflicts (2.0.3/2.0.4 exist precisely to relax
   analyzer/dart_style/dart_helper_utils ranges).
2. Regenerate (`dart run build_runner build`) and `dart analyze`.
3. One rename existed inside the 1.x line (1.1.2): `RouteInfo.replaceAll` ->
   `shouldReplaceAll`. The analyzer flags any survivor.
4. Do NOT start folding params into `RoutePolicy` here; that is the v3
   migration's job. Keep hops separate and verifiable.

## Rules

- One hop per commit; run the app's test suite between hops.
- Never mix an upgrade with feature work or "cleanups".
- After the final hop, re-run the full verification from the migration skill
  used (analyze, regenerate, deep-link host audit for v3, tests).

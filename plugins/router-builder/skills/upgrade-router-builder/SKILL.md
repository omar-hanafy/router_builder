---
name: upgrade-router-builder
description: Use when a project wants to update the router_builder package to a newer version and the migration path is unclear - "upgrade router_builder", "move to the latest router_builder", dependency bumps from 1.x or 2.x, or deciding whether an upgrade is breaking before touching code.
---

# Upgrade router_builder (version orchestrator)

Determine the installed version, pick the path, delegate the one breaking hop
to its dedicated skill. Never guess the version from imports alone.

## Step 1: Detect the installed and target versions

- Installed: `grep -A2 "router_builder" pubspec.lock` (the lockfile is truth;
  pubspec constraints can be stale).
- Target: latest 3.x unless the user pinned one (`dart pub outdated` shows it).
- Confirm with API tells when the lockfile is missing:
  `Routes`/`RoutesHelper`/`routes.g.dart` and `policy: RoutePolicy(...)` mean
  3.x; `MyRoutes`/`RouteInfoHelper`/`route_info_helper.dart` or flat params
  (`isGlobalOnly:`, `isIdSlug:`) mean 1.x/2.x.

## Step 2: Route by path

| From -> To | Path |
|---|---|
| 3.x -> newer 3.x | Bump constraint, `flutter pub get`, `dart run build_runner build`, `dart analyze`, run tests. 3.0.1 only relaxed the analyzer constraint; no code changes. |
| 2.x -> 3.x | BREAKING. Use the `migrate-v2-to-v3` skill (codemod + manual policy folds + regenerate + host audit). |
| 1.x -> 3.x | Two hops: first 1.x -> 2.0.4 (below), then `migrate-v2-to-v3`. |
| 1.x -> 2.x only | Deps-only hop (below). |
| 0.x | Never published to pub.dev; a 0.x source tree predates the unified deep-link system. Treat as legacy: consult the package MIGRATION_GUIDE.md appendix (v0 -> v1 deep-link registry migration), then continue up the chain. |

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

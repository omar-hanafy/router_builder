---
name: add-route
description: Use when adding, renaming, or removing a screen, route, tab, popup, redirect, or deep link in a Flutter app that uses the router_builder package - the one with @RT annotations, RouteInfo, RouteArgs, RoutePolicy, and a generated routes.g.dart with Routes/RoutesHelper classes.
---

# Add or change a route (router_builder)

Route data lives in `@RT()`-annotated `RouteInfo` declarations; a build_runner
aggregating builder generates `Routes` + `RoutesHelper`. Your job: declare the
route correctly, keep deep-link keys unique, regenerate, and wire it the way
THIS project wires routes.

## Step 1: Inspect the project before writing anything

- Confirm the dependency and major version in `pubspec.yaml`
  (`router_builder: ^3.x`). If it is 2.x, stop and use the
  `migrate-v2-to-v3` skill first, or write v2-style code deliberately.
- Find the route idiom: `grep -rn "@RT()" lib/ | head`. Two conventions exist
  in the wild: one central routes class, or one `static const route =
  RouteInfo(...)` per screen file. FOLLOW the existing one; when a project
  mixes both, match whichever convention hosts the routes most similar to
  yours (the dominant one when in doubt).
- Find the generated file (default `lib/routes.g.dart`; a custom `build.yaml`
  may rename it or the classes via `output`, `route_class_name`,
  `helper_class_name`).
- Find how the app installs defaults (`@RTConfig` + `installDefaults()` or
  `RouterBuilderConfig.setDefaults(...)`) and what they set. The BUILT-IN
  default is `mustBeAuthorized: true` (secure by default); apps often override
  it, and your route's policy must be written relative to the app's actual
  defaults, not the built-ins.
- Find the navigation adapter (how `RouteInfo`/`RouteArgs` reach GoRouter or
  Navigator). New routes usually need zero adapter changes when the adapter
  iterates `RoutesHelper` categories, and exactly one wiring change when routes
  are listed manually.

## Step 2: Declare the route

Pick ONE constructor:

| Need | Constructor | Notes |
|---|---|---|
| Normal screen | `RouteInfo(name, ...)` | Exactly one of `builder:`, `child:`, `pageBuilder:` (asserted). |
| Tab / shell branch | `RouteInfo.branch(name, branchIndex:, branchKey:, branchParentType:, ...)` | ALL branch routes in the app must share ONE enum type for `branchParentType`; `pushGlobally`/`isPopupRoute`/`deepLinkPushGlobally` are structurally forced false. |
| Redirect-only (no UI) | `RouteInfo.redirect(name, redirect:, ...)` | `isPopupRoute`/`visibleNavBar`/`shouldReplaceAll` forced false. |

- `path:` defaults to `/name`. Use templates for params: `path: '/orders/:orderId'`.
- Read params via `args?.pathParams?['orderId']`. `args?.id` is a heuristic
  (`pathParams['id']` else LAST segment); prefer named `pathParams` unless the
  param is literally `:id`.
- Behavior goes in `policy: RoutePolicy(...)` (or presets `RoutePolicy.global`
  / `.public` / `.popup`). The nine fields: `mustBeAuthorized`,
  `duplicateBehavior` (`DuplicateRouteBehavior.duplicate|refresh|doNothing` -
  "refresh instead of stacking a second copy" is
  `duplicateBehavior: DuplicateRouteBehavior.refresh`), `pushGlobally`,
  `isPopupRoute`, `visibleNavBar`, `isTopLevelOnly`, `shouldReplaceAll`,
  `deepLinkAllowed`, `deepLinkPushGlobally` (full semantics:
  `../debug-route-policy/references/policy-resolution.md`). Only set fields
  that differ from the APP defaults found in Step 1. Popups are normal routes
  with `isPopupRoute: true`; many apps subclass `RouteArgs` (DialogArgs-style)
  for them - follow the project.

## Step 3: Keep deep-link keys unique (before building)

Every route claims these keys: its NAME, its FIRST non-parameter path segment,
and every `deepLinkNames` alias. Any key claimed by two routes fails the build
with `RouterBuilderError: Deep-link key conflict(s)`. Before regenerating,
check planned keys against existing ones:

```bash
grep -rn "deepLinkNames\|RouteInfo(" lib/ | grep -v ".g.dart"
```

- Moving an alias between routes (marketing repurposes a short link): REMOVE it
  from the old route in the same change.
- Do NOT "fix" a conflict with `fail_on_conflict: false`; that silently drops
  the second route from `deepLinkMap`. Resolve the ownership for real.
- The runtime matcher resolves by path template and aliases only, NOT by route
  name; if users must open `myapp://<name>/...`, add the name itself to
  `deepLinkNames` (self-conflict is impossible).
- Alias-matched links fill `pathParams` POSITIONALLY against the template:
  `/item/42` fills `/orders/:orderId` because `:orderId` sits at index 1.
  Alias links whose segment layout differs from the template yield empty or
  wrong `pathParams` - keep alias URLs shaped like the template.

## Step 4: Regenerate and verify

```bash
dart run build_runner build   # current build_runner; the old --delete-conflicting-outputs flag is removed
dart analyze
```

- Build fails with `RouterBuilderError`: read the message; it names the exact
  declarations (conflicts, duplicate/non-const `@RTConfig`, branch enum
  mismatch). Fix the declaration, not the generator settings.
- New route missing from `routes.g.dart`: the annotation only discovers PUBLIC
  STATIC class fields and PUBLIC TOP-LEVEL const/final variables inside `lib/`.
- Route names become generated identifiers with non-alphanumerics replaced by
  `_` (name `settings.profile` -> `Routes.settings_profile`); duplicate names
  break compilation.

## Step 5: Wire and prove it

- Follow the project's navigation layer to expose the screen (usually nothing
  to do if the router iterates `RoutesHelper.normalRoutes`/`globalRoutes`/
  `branches`). For a fresh integration read
  `../setup-router-builder/references/go-router-integration.md`.
- Prove behavior with the generated surface, minimum:
  `RoutesHelper.fromName('name')` is non-null, and for deep-linkable routes
  `RoutesHelper.resolveDeepLink(Uri.parse(...), allowedHosts: [...])` returns
  the route with the expected `args.pathParams`. Run the project's tests; if
  the project has no test suite yet, add the proving test under `test/` anyway
  (it is real regression coverage, not scaffolding). Format touched files with
  `dart format`. Note for tests: `DeepLinkMatch` comes from the
  `package:router_builder/router_builder.dart` barrel; the generated file does
  not re-export it.

## Failure handling

- Dependency solve or analyzer conflicts: use the `debug-generation` skill.
- Route resolves but behaves unexpectedly (auth, popup, stacking, nav bar):
  use the `debug-route-policy` skill.
- Deep link does not open the screen at runtime: use the `debug-deep-links`
  skill.

---
name: setup-router-builder
description: Use when integrating the router_builder package into a Flutter app for the first time, wiring its RouteInfo/RouteArgs/RoutesHelper output into GoRouter or Navigator, setting app-wide route defaults (@RTConfig or RouterBuilderConfig), or restructuring how an app organizes its @RT route declarations.
---

# Set up router_builder in a Flutter app

router_builder generates typed route data + deep-link matching from `@RT()`
annotations; the app supplies the actual navigation (usually GoRouter). Setup
is: declare routes -> generate -> install defaults -> adapt to the router.

## Step 0: Inspect before adding anything

Check `pubspec.yaml`/`pubspec.lock` for an existing dependency and `grep -rn
"@RT()" lib/` for existing routes. If the package is already integrated, this
is not a setup task - route work belongs to `add-route`, behavior questions to
`debug-route-policy`. Note the app's state-management and DI choices; the
wiring below must live where this app puts singletons (provider, get_it,
plain globals), not in a new pattern.

## Step 1: Dependencies

```yaml
dependencies:
  router_builder: ^3.0.1
dev_dependencies:
  build_runner: ^2.15.0
```

No consumer `build.yaml` is needed: the builder auto-applies to dependents and
writes `lib/routes.g.dart` with classes `Routes` and `RoutesHelper`. Only add
one to override `output`, `route_class_name`, `helper_class_name`, or
`fail_on_conflict`.

## Step 2: Declare routes

Two proven organizations - pick with the user, then stay consistent:

- Central table: one `abstract class AppRoutes` holding `@RT() static const`
  fields (small apps, everything in one file).
- Co-located: each screen file declares its own `@RT() static const route =
  RouteInfo(...)` (scales to 90+ routes in production apps; the generator
  aggregates across all of `lib/`).

Minimum viable set: a home route, plus branches for each tab if the app has a
shell (`RouteInfo.branch` with ONE shared enum type across all branches). See
`add-route` for the full constructor/policy/deep-link rules.

## Step 3: App-wide defaults

Built-in defaults are secure by default: `mustBeAuthorized: true`,
`deepLinkAllowed: true`, `duplicateBehavior: duplicate`. Decide with the user
whether the app is default-private (auth apps) or default-public, then install
ONCE, before anything reads routes:

```dart
// Declarative (preferred for new apps): exactly one per package.
@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);

void main() {
  RoutesHelper.installDefaults();
  runApp(const App());
}
```

Imperative equivalent: `RouterBuilderConfig.setDefaults(const RoutePolicy(...))`
(note it MERGES over current defaults). Category getters
(`RoutesHelper.authorizedRoutes` etc.) recompute per access and silently use
built-ins if defaults were not installed first - install before building the
router.

## Step 4: Generate

```bash
dart run build_runner build
```

Failures here are declaration errors with exact messages (conflicts, duplicate
`@RTConfig`, branch enum mismatch) - see `debug-generation`.

## Step 5: Wire the router

For GoRouter (the battle-tested path), follow
[references/go-router-integration.md](references/go-router-integration.md):
RouteInfo->GoRoute adapters, `StatefulShellRoute.indexedStack` from
`RoutesHelper.branches`, a policy-aware push helper reading `effectiveX`
getters, an auth guard using `effectiveMustBeAuthorized` + `resumeTo`, and
deep-link entry via `RoutesHelper.resolveDeepLink`. For plain Navigator, the
same principles apply with `onGenerateRoute` + `RoutesHelper.fromName`.

Keep ONE choke point that converts `RouteArgs` to navigation calls; that is
where `effectiveDuplicateBehavior`, `effectivePushGlobally`, and
`effectiveShouldReplaceAll` get honored.

## Step 6: Verify end to end

1. `dart analyze` clean.
2. App boots to the home route.
3. A protected route redirects to auth when logged out and resumes after
   login (`resumeTo`).
4. `RoutesHelper.resolveDeepLink` resolves one https link (with the app's
   `allowedHosts`) and one custom-scheme link in a test.
5. Tab switching preserves per-branch stacks (if shells are used).

Platform deep-link registration (iOS associated domains, Android intent
filters/app links) is standard Flutter setup and out of this package's scope;
the package consumes URIs after the platform delivers them.

## Failure handling

Dependency solve or generation issues -> `debug-generation`. Unexpected
auth/popup/stack behavior -> `debug-route-policy`. Links not resolving ->
`debug-deep-links`.

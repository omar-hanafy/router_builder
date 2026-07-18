---
name: debug-route-policy
description: Use when a router_builder route behaves unexpectedly at runtime - auth gates firing on public screens or not firing on private ones, routes stacking duplicates or refusing to open twice, dialogs/sheets not treated as popups, navigation landing inside the wrong navigator or replacing the whole stack, redirect routes looping, nav bar visibility wrong, or RoutesHelper category lists (authorizedRoutes, globalRoutes, popupRoutes) not matching expectations.
---

# Debug route policy resolution (router_builder)

Every behavior flag is resolved from exactly three layers plus structural
constraints: `args.policy` -> `route.policy` -> `RouterBuilderConfig.defaults`,
then branch/redirect forcing. The complete field table, precedence, and
lifecycle rules are in
[references/policy-resolution.md](references/policy-resolution.md) - read it
first; do not reason from memory of other routing packages.

## Step 1: Capture the resolution chain, do not guess it

At the point of the surprising behavior (or in a quick test), print the
package's own diagnostics:

```dart
print(const JsonEncoder.withIndent('  ').convert(args.report()));   // has effectivePolicy
// or without per-call args:
print(const JsonEncoder.withIndent('  ').convert(route.report()));  // has policy + resolvedPolicy
print(RouterBuilderConfig.defaults.toMap());
print(RouterBuilderConfig.isConfigured);
```

`report()` is JSON-safe by design. Compare `policy` (declared) against
`resolvedPolicy`/`effectivePolicy` (resolved) field by field; the first layer
that sets a field non-null wins.

## Step 2: Match the finding to the known causes

| Finding | Cause |
|---|---|
| Route is private though never marked so | Built-in default `mustBeAuthorized: true`; the app never opted the route out (`RoutePolicy.public`) or never installed public-by-default app defaults |
| Guard treats missing args as public | `RouteArgsX.requiresAuth` on a NULL `RouteArgs?` returns false; construct args for guard checks instead of passing null |
| Category getters "wrong" (authorizedRoutes lists everything, globalRoutes empty) | Getters recompute per access against CURRENT defaults; they were read before `installDefaults()`/`setDefaults()` ran |
| Defaults "did not apply" | `setDefaults` MERGES over current defaults (accumulates); a field set by an earlier call survives later calls that omit it. In tests, missing `RouterBuilderConfig.reset()` leaks state between tests |
| Branch/tab route ignores `pushGlobally`/`isPopupRoute`; deep-linked tab opens in shell "despite" deepLinkPushGlobally | Structural constraints: branches force those three false; redirect routes force `isPopupRoute`/`visibleNavBar`/`shouldReplaceAll` false. Release builds force silently; debug builds assert |
| Assertion `Branch route "x": pushGlobally/isPopupRoute/deepLinkPushGlobally are forced false` | A route/args policy explicitly sets a forced field - delete that field from the policy |
| Per-call override "ignored" | The app's adapter reads route-level getters (`route.pushGlobally`) instead of args-level (`args.effectivePushGlobally`) at its push choke point |
| Duplicate handling wrong | Adapter must implement `effectiveDuplicateBehavior` (`duplicate`/`refresh`/`doNothing`); the package only resolves the value, the adapter enacts it |
| `copyWith` failed to clear a field | `RoutePolicy.copyWith` cannot reset a field to null; build a fresh `RoutePolicy` instead |

## Step 3: Fix at the right layer

Fix where the semantics belong: app-wide -> defaults (`@RTConfig`/
`setDefaults`), per-route -> `route.policy`, per-navigation -> `args.policy`,
enforcement gap -> the app's adapter (the package resolves values; the adapter
must read `effectiveX` at ONE choke point). Never fix a per-route problem by
changing global defaults.

## Step 4: Verify

Re-run the Step 1 probe and assert the resolved field now has the intended
value; add a unit test pinning the resolution (`RouterBuilderConfig.reset()` in
setup, install the app policy, assert `route.X`/`args.effectiveX`). The
package's precedence is deterministic and fully testable without widgets.

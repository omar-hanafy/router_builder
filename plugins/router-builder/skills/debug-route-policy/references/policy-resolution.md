# RoutePolicy resolution reference (router_builder v3)

Verified against `lib/src/models/route_policy.dart`, `route_info.dart`,
`route_args.dart`, and `lib/src/router_config.dart` at v3.0.x.

## The nine fields and built-in defaults

Every `RoutePolicy` field is nullable. `null` means "not set at this level,
defer down the chain". `RouterBuilderConfig` holds one complete policy so
resolution always terminates with non-null values.

| Field | Built-in default | Meaning |
|---|---|---|
| `mustBeAuthorized` | `true` | Authentication required. Secure by default: a login/landing route is PRIVATE unless it opts out. |
| `duplicateBehavior` | `duplicate` | When target route is already current: `duplicate` push again, `refresh` replace in place, `doNothing` cancel. |
| `pushGlobally` | `false` | Push on the root navigator (over shells/tabs). |
| `isPopupRoute` | `false` | Presented as dialog/sheet/popup. |
| `visibleNavBar` | `true` | Primary nav UI stays visible. |
| `isTopLevelOnly` | `false` | Route stays at the top level of its navigator. |
| `shouldReplaceAll` | `false` | Navigation replaces the entire stack. |
| `deepLinkAllowed` | `true` | Route is reachable via deep links (checked at match time, resolved). |
| `deepLinkPushGlobally` | `true` | A deep link to this route pushes on the root navigator. |

Presets: `RoutePolicy.global` (`pushGlobally: true`), `RoutePolicy.public`
(`mustBeAuthorized: false`), `RoutePolicy.popup` (`isPopupRoute: true`).

## Resolution order

`merge` is the only primitive: `a.merge(b)` keeps `a`'s non-null fields and
fills gaps from `b`.

- Route scope: `route.resolvedPolicy = constrain(route.policy ?? empty).merge(RouterBuilderConfig.defaults)`
- Call scope: `args.effectivePolicy = route.constrain((args.policy ?? empty).merge(route.policy)).merge(RouterBuilderConfig.defaults)`

Precedence, highest first: `args.policy` -> `route.policy` -> global defaults.
Structural constraints always win because `constrain` writes non-null `false`
values that survive the later defaults merge.

## Structural constraints (`RouteInfo.constrain`)

| Route kind | Forced `false` | Still free via policy |
|---|---|---|
| `RouteInfo.branch` | `pushGlobally`, `isPopupRoute`, `deepLinkPushGlobally` | `mustBeAuthorized`, `duplicateBehavior`, `visibleNavBar`, `isTopLevelOnly`, `shouldReplaceAll`, `deepLinkAllowed` |
| `RouteInfo.redirect` | `isPopupRoute`, `visibleNavBar`, `shouldReplaceAll` | `mustBeAuthorized`, `pushGlobally`, `duplicateBehavior`, `isTopLevelOnly`, `deepLinkAllowed`, `deepLinkPushGlobally` |
| standard | none | all nine |

In debug builds an `assert` fires if `route.policy` or `args.policy` sets a
forced field to `true` (message names the route and the forced fields). In
release builds the value is silently forced to `false`.

## Read sites

- `RouteInfo` resolved getters (non-null, same names as the fields):
  `route.mustBeAuthorized`, `route.duplicateBehavior`, `route.pushGlobally`,
  `route.isPopupRoute`, `route.visibleNavBar`, `route.isTopLevelOnly`,
  `route.shouldReplaceAll`, `route.deepLinkAllowed`, `route.deepLinkPushGlobally`.
  These do NOT include per-call overrides.
- `RouteArgs` effective getters (non-null, fold args over route over defaults):
  `args.effectiveMustBeAuthorized`, `args.effectiveDuplicateBehavior`,
  `args.effectivePushGlobally`, `args.effectiveIsPopupRoute`,
  `args.effectiveVisibleNavBar`, `args.effectiveIsTopLevelOnly`,
  `args.effectiveShouldReplaceAll`, `args.effectiveDeepLinkAllowed`,
  `args.effectiveDeepLinkPushGlobally`.
- `RouteArgsX.requiresAuth` on a NULLABLE `RouteArgs?` returns
  `effectiveMustBeAuthorized`, but `false` when the args object is null, which
  inverts the secure-by-default rule. Guard code should not treat null args as
  public by accident.

## Global defaults lifecycle (`RouterBuilderConfig`)

- `defaults` is always complete (all nine non-null).
- `setDefaults(policy)` MERGES the given policy over the CURRENT defaults
  (`policy.merge(_defaults)`). It does not replace wholesale, and repeated
  calls accumulate. A field you never mention keeps its previous value.
- `reset()` restores built-ins and clears `isConfigured` (intended for tests;
  call it in `setUp`/`tearDown` when tests mutate defaults).
- `markConfigured()` / `isConfigured`: bookkeeping flag set by the generated
  `installDefaults()`; nothing in the package enforces it.
- Declarative alternative: annotate exactly one `const RoutePolicy` with
  `@RTConfig()`; the generated `RoutesHelper.installDefaults()` then calls
  `setDefaults(thatPolicy)` + `markConfigured()`. Call it first in `main()`.
  Without an `@RTConfig`, `installDefaults()` only marks configured.

## Timing pitfall: category getters

`RoutesHelper.normalRoutes / globalRoutes / popupRoutes / topLevelRoutes /
authorizedRoutes / redirectRoutes` are RUNTIME getters over `allRoutes` using
the resolved getters. They recompute on every access and therefore change
meaning depending on the defaults installed at the moment of the call. Reading
them before `installDefaults()` / `setDefaults()` silently uses built-in
defaults (for example `authorizedRoutes` returns every route that did not opt
out, because `mustBeAuthorized` defaults to `true`).

## Diagnostics

All three models expose a JSON-safe `report()`:

- `policy.report()` - raw field map, enums by name.
- `route.report()` - structural fields, presence flags (`hasBuilder`,
  `hasChild`, `hasPageBuilder`, `hasRedirect`, `hasTitle`,
  `hasDeepLinkHandler`), the declared `policy`, and `resolvedPolicy`.
- `args.report()` - navigation payload (`id`, `pathParams`, `queryParams`,
  `object`, `isFromDeeplink`), shallow `route`/`resumeTo`/`comingFrom`
  summaries, and `effectivePolicy`.

To answer "why is this route behaving like X", print `args.report()` (or
`route.report()` when there are no per-call args) and compare `policy` vs
`resolvedPolicy`/`effectivePolicy` field by field, then check
`RouterBuilderConfig.defaults` and the constraint table above.

## Equality note

`RouteInfo.props` covers `name`, `path`, `isBranch`, `forRedirectionOnly`,
branch fields, `deepLinkNames`, and `policy`. Builder/child/pageBuilder/title
closures are excluded, so two routes with the same name+path+policy compare
equal even with different widgets.

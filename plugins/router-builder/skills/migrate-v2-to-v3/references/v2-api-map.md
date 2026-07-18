# v2 -> v3 API map (ground truth)

Derived from the published `router_builder 2.0.4` sources and the v3.0.x
sources. Use this to recognize v2 code and to know its exact v3 replacement.

## Dependency and tooling

| v2 | v3 |
|---|---|
| `router_builder: ^2.0.0` (analyzer >=9 <11 era) | `router_builder: ^3.0.1` (analyzer >=9 <13) |
| Consumer `build.yaml` importing `package:router_builder/generators/generate_route_info_helper.dart`, output `lib/route_info_helper.dart` | No consumer build.yaml needed at all (builder auto-applies with new defaults), or one importing `package:router_builder/builder.dart` when overriding options |
| Generated `lib/route_info_helper.dart` with `MyRoutes` + `RouteInfoHelper` | Generated `lib/routes.g.dart` with `Routes` + `RoutesHelper` (old names can be pinned via builder options `output`, `route_class_name`, `helper_class_name`) |

## Imports

| v2 import | v3 import |
|---|---|
| `package:router_builder/models/models.dart` | `package:router_builder/router_builder.dart` |
| `package:router_builder/models/route_info.dart` (also `route_args.dart`, `route_policy.dart`, `duplicate_route_behavior.dart`) | same single barrel |
| `package:router_builder/annotations/route.dart` | same single barrel |
| `package:router_builder/deeplink/deep_link_matcher.dart` | same single barrel |
| `package:router_builder/handlers/deep_link_handler.dart` | same single barrel |
| `package:router_builder/router_config.dart` | same single barrel |
| `import '.../route_info_helper.dart'` | `import '.../routes.g.dart'` |

## RouteInfo constructors

v2 `RouteInfo(...)` flat params removed in v3; each maps to a `RoutePolicy`
field inside `policy:`:

| v2 flat param | v3 policy field |
|---|---|
| `isGlobalOnly:` | `policy: RoutePolicy(pushGlobally: ...)` (RENAMED) |
| `mustBeAuthorized:` | `policy: RoutePolicy(mustBeAuthorized: ...)` |
| `visibleNavBar:` | `policy: RoutePolicy(visibleNavBar: ...)` |
| `isPopupRoute:` | `policy: RoutePolicy(isPopupRoute: ...)` |
| `shouldReplaceAll:` | `policy: RoutePolicy(shouldReplaceAll: ...)` |
| `isTopLevelOnly:` | `policy: RoutePolicy(isTopLevelOnly: ...)` |
| `duplicateBehavior:` | `policy: RoutePolicy(duplicateBehavior: ...)` |
| `deepLinkAllowed:` | `policy: RoutePolicy(deepLinkAllowed: ...)` |

Notes:
- v2 already HAD an optional `policy:` param (since 1.2.0). Code may mix flat
  params and a policy; when folding, the v2 override order put explicit flat
  args over the policy object. Merge conflicts field-by-field, flat value wins.
- If a route ends up with `policy: RoutePolicy(pushGlobally: true)` only,
  prefer the preset `RoutePolicy.global`; `mustBeAuthorized: false` only ->
  `RoutePolicy.public`; `isPopupRoute: true` only -> `RoutePolicy.popup`.
- `RouteInfo.branch` in v2 had NO `isGlobalOnly`/`isPopupRoute` params (forced
  false); in v3 branches also force `deepLinkPushGlobally` false.
- `RouteInfo.redirect` v2 params `isGlobalOnly`/`visibleNavBar` etc. follow the
  same fold; v3 redirect routes force `isPopupRoute`/`visibleNavBar`/
  `shouldReplaceAll` false, and setting them in policy asserts in debug.

## RouteInfo read sites

v2 flat getters were nullable or had scattered defaults. v3 resolved getters
are non-null; drop the null-coalescing:

| v2 read | v3 read |
|---|---|
| `route.isGlobalOnly ?? false` | `route.pushGlobally` |
| `route.mustBeAuthorized ?? true` | `route.mustBeAuthorized` |
| `route.duplicateBehavior ?? DuplicateRouteBehavior.duplicate` | `route.duplicateBehavior` |
| `route.isPopupRoute ?? false` | `route.isPopupRoute` |
| `route.visibleNavBar` (non-null in v2) | `route.visibleNavBar` (unchanged spelling) |
| `route.shouldReplaceAll` / `route.isTopLevelOnly` / `route.deepLinkAllowed` | unchanged spelling, now policy-resolved |

## RouteArgs

v2 constructor params removed in v3:

| v2 | v3 |
|---|---|
| `RouteArgs(r, pushGlobally: true)` | `RouteArgs(r, policy: RoutePolicy(pushGlobally: true))` |
| `RouteArgs(r, mustBeAuthorized: false)` | `RouteArgs(r, policy: RoutePolicy(mustBeAuthorized: false))` |
| `RouteArgs(r, duplicateBehavior: b)` | `RouteArgs(r, policy: RoutePolicy(duplicateBehavior: b))` |
| `RouteArgs(r, isIdSlug: true)` | REMOVED, no replacement flag. Detect from the value at the read site (e.g. `int.tryParse(args.id ?? '') == null`) or model it on a `RouteArgs` subclass field. |
| Subclass forwarding `super.pushGlobally` / `super.mustBeAuthorized` / `super.duplicateBehavior` / `super.isIdSlug` | Forward `super.policy` (and keep the surviving params: `id`, `queryParams`, `pathParams`, `object`, `resumeTo`, `comingFrom`, `isFromDeeplink`) |

Kept in v3 unchanged: `id`, `queryParams`, `pathParams`, `object`, `resumeTo`,
`comingFrom`, `isFromDeeplink`, `policy`, `copyWith`, `fromUri`.
v2's four `effectiveX` getters survive and v3 adds the remaining five
(`effectiveVisibleNavBar`, `effectiveIsTopLevelOnly`,
`effectiveShouldReplaceAll`, `effectiveDeepLinkAllowed`,
`effectiveDeepLinkPushGlobally`).

Semantic delta at read sites: v2 wiring often OR-folded route and args
(`(route.isGlobalOnly ?? false) || args.effectivePushGlobally`), which meant a
per-call policy could never turn a global route non-global. v3's
`args.effectivePushGlobally` alone lets an explicit
`args.policy(pushGlobally: false)` win over the route. Identical behavior for
every call site that never passes an explicit false; flag any that do.

## RouterBuilderConfig

| v2 | v3 |
|---|---|
| `RouterBuilderConfig.setDefaults(mustBeAuthorized: ..., duplicateBehavior: ..., pushGlobally: ..., isPopupRoute: ...)` (named params) | `RouterBuilderConfig.setDefaults(const RoutePolicy(...))` (one positional RoutePolicy), or declare `@RTConfig() const appRoutePolicy = RoutePolicy(...)` and call the generated `RoutesHelper.installDefaults()` in `main()` |
| `RouterBuilderConfig.defaults = ...` (settable in some v2 code) | `defaults` is read-only; only `setDefaults` mutates |

v3's `setDefaults` MERGES the given policy over the current (initially
built-in, complete) defaults, so converting a v2 call that set only some named
params into a `RoutePolicy` with only those fields is behavior-preserving -
unmentioned fields keep their defaults exactly as in v2.

## Deep links

| v2 | v3 |
|---|---|
| Allowed-host check used substring `host.contains(allowed)`; `app.example` also matched `myapp.example.evil.test` | Exact-or-suffix: `host == allowed \|\| host.endsWith('.allowed')`. AUDIT the allowed-hosts list: hosts that only matched via substring are now rejected. |
| Deep-link key conflicts logged a warning and silently kept the first route | Conflicts FAIL THE BUILD by default (`fail_on_conflict: true`) |
| Deep-link push-global hardcoded true in matcher | Policy field `deepLinkPushGlobally` (default true), branch routes force false |

## Typedefs and misc

- `ScreenTitleBuilder` v2 `String Function(BuildContext, [RouteArgs?])` -> v3
  `String Function(BuildContext, RouteArgs?)`. Existing lambdas written as
  `(context, [args]) => ...` remain assignable in v3; new code should use
  `(context, args)`.
- `report()` in v3 is JSON-safe on `RoutePolicy`/`RouteInfo`/`RouteArgs`
  (closures become presence flags); v2's report embedded raw closures.
- `allRoutes` in v3 INCLUDES redirect-only routes; v2 omitted them. Code that
  iterated `allRoutes` assuming every route has UI must now check
  `forRedirectionOnly`.
- Category getters (`normalRoutes`, `globalRoutes`, ...) are runtime-derived in
  v3 and reflect installed defaults at call time.

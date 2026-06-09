# Router Builder v3 - Design

Status: Draft for review
Date: 2026-06-09
Scope: full public surface - `lib/` layout and barrels, models, config, annotations,
deep-link layer, and the code generator.

This is a major version. v3 is the one cheap window for breaking changes, so the design
covers the whole surface, not only `RoutePolicy`. Where a change is additive, it is called
out so it can ship earlier in a v2.x bridge (section 13).

---

## 1. Background and motivation

`RoutePolicy` was introduced in 1.2.0 to group route behavior. Flat fields were kept for
compatibility and deprecated in 2.1.0, with resolution logic spread across several sites.
A full read of the package surfaced issues beyond policy:

- **Resolution logic is duplicated** across `RouteInfo.localPolicy`, `RouteArgs.localPolicy`,
  the `effectiveX` getters, `RouterBuilderConfig.setDefaults`, and the generator.
- **The generated file can report false information** (categories keyed on values the
  build step cannot reliably know; see section 7).
- **No `lib/src/` encapsulation**: every file is deep-importable, so internals cannot
  change without breaking consumers.
- **The generator is unconfigurable**: `BuilderOptions` is ignored; class names and output
  path are hardcoded.
- **Deep-link host matching uses substring `.contains()`** (a security footgun), and
  redirect-only routes are absent from `allRoutes`.
- **No tests and no example.**

### Real-world usage signals (Saber app)

- `pushGlobally` is by far the most threaded per-call override; `duplicateBehavior` second.
- `RouteArgs` is subclassed (`DialogArgs`, `BottomSheetArgs`, `CupertinoModalArgs`) via
  super-parameters, so the constructor shape is an extensibility contract.
- Route-level facts (`route.visibleNavBar`, `route.shouldReplaceAll`, `route.isGlobalOnly`)
  are read as plain non-null values in hot paths.
- Consumers deep-import `package:router_builder/models/models.dart` and reference
  `MyRoutes` / `RouteInfoHelper` widely.

## 2. Goals and non-goals

**Goals**

- One comprehensive `RoutePolicy` as the single home for cascading settings, globally
  defaultable in `main()`.
- Generated artifacts that cannot drift from runtime truth.
- A conventional, encapsulated package layout (`lib/src/` + one public barrel).
- A configurable generator (class names, output path, conflict policy).
- A safe, correct deep-link layer.
- Ergonomic, non-null resolution with no second model type.

**Non-goals**

- No `ResolvedRoutePolicy` (or any new resolved type).
- No new deep-link matching features (wildcards, catch-all) beyond the correctness fixes.
- No generic-typed `RouteArgs` payload; `object` stays `Object?`.

## 3. Resolved design decisions

| # | Decision |
|---|----------|
| D1 | `RoutePolicy` holds all cascading config (9 fields). |
| D2 | No new model type; resolution via getters returning `RoutePolicy` and non-null `effectiveX`. |
| D3 | `RouterBuilderConfig.defaults` is one complete, encapsulated `RoutePolicy`, overridable wholesale. |
| D4 | `RouteInfo` keeps same-named non-null resolved getters while data moves into `policy`. |
| D5 | `RouteInfo` / `RouteArgs` constructors drop flat behavioral params (use `policy:`). |
| D6 | `RouteArgs` keeps one clean public constructor (delete `RouteArgs._`); stays subclassable. |
| D7 | Generated behavior categories are runtime-derived (Option A). |
| D8 | New `@RTConfig` annotation on a `const RoutePolicy`; generated install wiring; build-error on duplicates. |
| D9 | Rename `isGlobalOnly` -> `pushGlobally` everywhere. |
| D10 | Adopt `lib/src/` layout with a single public `router_builder.dart` barrel and a separate `builder.dart` build entrypoint. |
| D11 | Generator reads `BuilderOptions`: `output`, `route_class_name`, `helper_class_name`, `fail_on_conflict`. |
| D12 | Default generated output: `lib/routes.g.dart`, classes `Routes` and `RoutesHelper`. |
| D13 | Deep-link host matching becomes exact-or-suffix (no substring); deep-link key conflicts fail the build by default; deep-link push-global becomes the `deepLinkPushGlobally` policy field (default true). |
| D14 | `allRoutes` contains every annotated route (including redirect-only); categories are subsets derived from it. |
| D15 | `@RT` discovery broadens to top-level consts/finals in addition to class static fields (not enums/mixins/extensions). |
| D16 | Unify route builder typedef signatures; remove `isIdSlug` from `RouteArgs`; drop stale `replaceAll` parsing. |
| D17 | `report()` becomes a rich, JSON-safe diagnostic on all models via dhu's `toJsonMap()`; closures become presence flags. |

## 4. The model (policy)

### 4.1 `RoutePolicy` (comprehensive, all nullable)

Nullable = "not set at this level; defer down the chain."

| Field | Type | Global default | Meaning |
|-------|------|----------------|---------|
| `mustBeAuthorized` | `bool?` | `true` | Authentication required. |
| `duplicateBehavior` | `DuplicateRouteBehavior?` | `duplicate` | Behavior when the route is already on the stack. |
| `pushGlobally` | `bool?` | `false` | Push on the root navigator. |
| `isPopupRoute` | `bool?` | `false` | Presented as dialog/sheet/popup. |
| `visibleNavBar` | `bool?` | `true` | Primary nav UI stays visible. |
| `isTopLevelOnly` | `bool?` | `false` | Stays at the top level of its navigator. |
| `shouldReplaceAll` | `bool?` | `false` | Navigation replaces the entire stack. |
| `deepLinkAllowed` | `bool?` | `true` | Reachable via deep links. |
| `deepLinkPushGlobally` | `bool?` | `true` | When reached via a deep link, push on the root navigator. |

```dart
class RoutePolicy extends Equatable {
  const RoutePolicy({ /* the 9 nullable fields */ });

  RoutePolicy merge(RoutePolicy? lower);   // this wins per-field, lower fills gaps
  RoutePolicy copyWith({ /* 9 fields */ });

  static const RoutePolicy global = RoutePolicy(pushGlobally: true);
  static const RoutePolicy public = RoutePolicy(mustBeAuthorized: false);
  static const RoutePolicy popup  = RoutePolicy(isPopupRoute: true);

  @override
  List<Object?> get props => [/* all 9 */];
}
```

`merge` is the single resolution primitive.

### 4.2 `RouterBuilderConfig`

Complete, encapsulated defaults so resolution always terminates non-null and the scattered
hardcoded fallback constants disappear.

```dart
class RouterBuilderConfig {
  RouterBuilderConfig._();

  static RoutePolicy _defaults = const RoutePolicy(
    mustBeAuthorized: true, duplicateBehavior: DuplicateRouteBehavior.duplicate,
    pushGlobally: false, isPopupRoute: false, visibleNavBar: true,
    isTopLevelOnly: false, shouldReplaceAll: false, deepLinkAllowed: true,
    deepLinkPushGlobally: true,
  );

  static RoutePolicy get defaults => _defaults;            // always complete
  static void setDefaults(RoutePolicy policy) => _defaults = policy.merge(_defaults);
  static void reset();

  static bool get isConfigured;     // for the optional @RTConfig fail-fast
  static void markConfigured();
}
```

### 4.3 `RouteInfo` (structure + resolved getters)

**Structural fields kept:** `name`, `path`, `title`, `builder`/`child`/`pageBuilder`,
`redirect`, `deepLinkNames`, `deepLinkHandler`, branch fields, `forRedirectionOnly`, `policy`.

**Removed from constructors (now via `policy:`):** `isGlobalOnly`, `mustBeAuthorized`,
`isPopupRoute`, `duplicateBehavior`, `visibleNavBar`, `isTopLevelOnly`, `shouldReplaceAll`,
`deepLinkAllowed`.

```dart
/// Applies branch/redirect structural constraints (section 6). Shared by both scopes.
RoutePolicy constrain(RoutePolicy p);

/// Route policy over global defaults, constrained. All fields non-null at runtime.
RoutePolicy get resolvedPolicy =>
    constrain((policy ?? const RoutePolicy()).merge(RouterBuilderConfig.defaults));

// Same-named non-null getters delegate to resolvedPolicy, so `route.X` reads survive:
bool get mustBeAuthorized; DuplicateRouteBehavior get duplicateBehavior;
bool get pushGlobally;     // was isGlobalOnly
bool get isPopupRoute; bool get visibleNavBar; bool get isTopLevelOnly;
bool get shouldReplaceAll; bool get deepLinkAllowed; bool get deepLinkPushGlobally;
```

**Equality fix:** `props` includes the comparable structural fields (`name`, `path`,
`deepLinkNames`, branch fields, `forRedirectionOnly`, `policy`); behavioral fields are
compared through `policy`; function/widget fields stay excluded. Fixes today's omissions.

**Import fix:** import `route_policy.dart` directly, not via `route_args.dart`.

### 4.4 `RouteArgs` (per-call)

One clean public constructor (delete `RouteArgs._`); `isIdSlug` removed (D16):

```dart
const RouteArgs(
  this.route, {
  this.id, this.queryParams, this.pathParams, this.object,
  this.resumeTo, this.comingFrom, this.isFromDeeplink = false, this.policy,
});
```

Call-scope resolution folds `args -> route -> defaults`, then constraints last so a per-call
policy cannot break a structural constraint:

```dart
RoutePolicy get effectivePolicy => route.constrain(
      (policy ?? const RoutePolicy()).merge(route.policy).merge(RouterBuilderConfig.defaults),
    );

bool get effectiveMustBeAuthorized => effectivePolicy.mustBeAuthorized!;
DuplicateRouteBehavior get effectiveDuplicateBehavior => effectivePolicy.duplicateBehavior!;
bool get effectivePushGlobally => effectivePolicy.pushGlobally!;
bool get effectiveIsPopupRoute => effectivePolicy.isPopupRoute!;
bool get effectiveVisibleNavBar => effectivePolicy.visibleNavBar!;
bool get effectiveIsTopLevelOnly => effectivePolicy.isTopLevelOnly!;
bool get effectiveShouldReplaceAll => effectivePolicy.shouldReplaceAll!;
bool get effectiveDeepLinkAllowed => effectivePolicy.deepLinkAllowed!;
```

**Subclassing:** subclasses forward via `super.policy` (and the surviving super-params).
`DialogArgs`/`BottomSheetArgs`/`CupertinoModalArgs` migrate `super.pushGlobally` ->
`super.policy`; callers fold flags into `policy:`.

### 4.5 Diagnostics: `report()` (all models)

`RoutePolicy`, `RouteInfo`, and `RouteArgs` each expose a rich, JSON-safe `report()` for
analytics and custom bug reports, built on `dart_helper_utils`' re-exported `toJsonMap()`
(from `convert_object`). That normalizer recurses values safely: enums -> `.name`,
`Uri`/`BigInt` -> string, `DateTime` -> ISO, bytes -> base64, `Map`/`Iterable` recursed,
optional cycle detection, a `toEncodable` hook, and unknown types falling back to
`toString()` so it never throws.

```dart
Map<String, dynamic> report({
  JsonOptions options = const JsonOptions(),
  Object? Function(dynamic)? toEncodable,   // teach it your `object` payloads
}) => _rawReport().toJsonMap(options: options, toEncodable: toEncodable);
```

- **Closures and widgets are not dumped**; they become presence flags (`hasBuilder`,
  `hasChild`, `hasPageBuilder`, `hasRedirect`, `hasTitle`, `hasDeepLinkHandler`).
- `RouteInfo.report()` emits structural fields + presence flags + the **resolved** policy.
- `RouteArgs.report()` emits the navigation (`id`, params, `object`, `isFromDeeplink`) + the
  **effective** policy + a shallow summary of `route`/`resumeTo`/`comingFrom` (name + id) to
  avoid cycles and oversized payloads.
- The returned map is guaranteed `jsonEncode`-able; `toJsonString()` is available via dhu.

Today's `report()` embeds closures and widgets, so `jsonEncode` throws; this makes it fit its
stated purpose.

## 5. Resolution model

Precedence (high to low): `args.policy` -> `route.policy` -> `RouterBuilderConfig.defaults`
(complete -> non-null result), then branch/redirect constraints applied last. One `merge`
fold powers both route scope (`resolvedPolicy`) and call scope (`effectivePolicy`).

## 6. Branch / redirect structural constraints

| Route kind | Forced | Free via policy |
|------------|--------|-----------------|
| `branch` | `pushGlobally=false`, `isPopupRoute=false` | `mustBeAuthorized`, `duplicateBehavior`, `visibleNavBar`, `isTopLevelOnly`, `deepLinkAllowed` |
| `redirect` (`forRedirectionOnly`) | `isPopupRoute=false`, `visibleNavBar=false`, `shouldReplaceAll=false` | `mustBeAuthorized`, `pushGlobally`, `deepLinkAllowed` |
| standard | none | all |

A debug `assert` may warn when a branch/redirect policy sets a forced field (O3).

## 7. Generator

### 7.1 Runtime-derived categories (correctness)

The build step cannot soundly know runtime-resolved values: global defaults are installed
at runtime in `main()` and the generator cannot prove that installation runs. So v3 emits
only statically-true data and derives behavior categories at runtime.

**Generated as data:** `allRoutes` (every annotated route, D14), `Routes` constants, branch
map and per-enum branch lists, `deepLinkMap` key topology with build-time conflict
detection, `fromName`.

**Runtime getters on the helper** (computed from `allRoutes` via the resolved getters, so
they reflect policy + installed defaults): `normalRoutes`, `globalRoutes`, `popupRoutes`,
`topLevelRoutes`, `authorizedRoutes`, plus `redirectRoutes`.

`deepLinkAllowed` no longer excludes keys at build time; deep-link resolution checks
`route.deepLinkAllowed` (resolved) at match time, so a global `deepLinkAllowed: false`
default is honored.

These getters recompute on access (route counts are small; negligible cost), and degrade
gracefully: if defaults are not installed, built-in defaults apply consistently to both
reads and resolution (never divergent). Same names as today, so readers are unaffected.

### 7.2 Configurability (D11/D12)

`BuilderOptions` (via `build.yaml` `options:`):

| Option | Default | Effect |
|--------|---------|--------|
| `output` | `lib/routes.g.dart` | Output asset path (drives `buildExtensions`). |
| `route_class_name` | `Routes` | Generated route-constants class. |
| `helper_class_name` | `RoutesHelper` | Generated helper class. |
| `fail_on_conflict` | `true` | Deep-link key conflict fails the build. |

`generateRouteInfoHelperBuilder(options)` reads these and constructs the builder with a
matching `buildExtensions` (`{$package$: [output]}`). All names default per D12 and are
overridable; existing projects pin the old names if they prefer.

### 7.3 Discovery and parsing fixes

- `@RT` discovery broadens to top-level consts/finals as well as class static fields (D15);
  enums/mixins/extensions are not scanned. Supported sites are documented.
- Best-effort constant evaluation (not literal-only) for policy values, using the analyzer
  constant API already imported.
- Stale `replaceAll` parsing removed (D16); it referenced a renamed field and is moot under
  runtime-derivation.

## 8. `@RTConfig` (global defaults DX)

```dart
@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false, deepLinkAllowed: false);
```

- Generator scans for it; more than one declaration is a build error; it must annotate a
  `const RoutePolicy`.
- Generator emits the value and install wiring, e.g. `RoutesHelper.installDefaults()` which
  calls `RouterBuilderConfig.setDefaults(...)` and `markConfigured()`. The app calls it once
  in `main()`.
- Optional debug fail-fast: when a config exists, navigation helpers may
  `assert(RouterBuilderConfig.isConfigured)`. "Must run in `main`" is not statically
  provable; with runtime-derived categories nothing about correctness depends on it.

## 9. Package structure (D10)

```
lib/
  router_builder.dart      // public runtime barrel (the only runtime import)
  builder.dart             // build entrypoint: generateRouteInfoHelperBuilder
  src/
    annotations/route.dart           // RT, RTConfig
    models/route_policy.dart
    models/duplicate_route_behavior.dart   // split out (O2)
    models/route_info.dart
    models/route_args.dart
    router_config.dart
    deeplink/deep_link_matcher.dart
    handlers/deep_link_handler.dart
    generators/generate_route_info_helper.dart
```

- `router_builder.dart` exports only the runtime public API. It does NOT export the
  generator (which pulls in `analyzer` / `build` / `dart_style`).
- `builder.dart` exposes the builder factory; `build.yaml` imports
  `package:router_builder/builder.dart`.
- The generated file imports the barrel, not deep paths.
- Breaking: deep imports (`package:router_builder/models/...`) must move to the barrel.

## 10. Deep-link layer (D13/D14)

- **Host matching** replaces substring `.contains()` with exact-or-suffix:
  `host == allowed || host.endsWith('.$allowed')`. Accepts `myapp.com` and `www.myapp.com`
  for allowed `myapp.com`; rejects `evil-myapp.com`. Security fix.
- **`allRoutes` includes redirect-only routes** so `fromName` and `resolveDeepLink` can find
  them; `deepLinkAllowed` (resolved) still gates matching.
- **Key conflicts fail the build** by default (`fail_on_conflict`), instead of logging and
  silently dropping the loser.
- **Deep-link push-global is policy-driven** via `RoutePolicy.deepLinkPushGlobally`
  (default `true`). The matcher reads `route.resolvedPolicy.deepLinkPushGlobally` instead of
  hardcoding `true` in `_buildArgs`, and sets the resolved args' `pushGlobally` accordingly.
  Opt out per route (`policy: RoutePolicy(deepLinkPushGlobally: false)`) or app-wide
  (`@RTConfig` / `setDefaults`). Branch routes still never push globally (the structural
  constraint wins), so a deep-linked tab lands in its shell.

## 11. Model / API cleanups (D16)

- **Typedefs unified** to `(BuildContext context, RouteArgs? args)` across
  `ScreenTitleBuilder`, `ScreenWidgetBuilder`, `ScreenPageBuilder`, `RouterRedirect`
  (today `ScreenTitleBuilder` uses an optional positional, the rest required).
- **`isIdSlug` removed** from `RouteArgs`: the package never acts on it, and slug-vs-id is a
  per-route concern. Detect from the value at the gate (`int.tryParse(args.id ?? '') == null`);
  for ambiguous all-digit slugs, model it per route via a `RouteArgs` subclass field or a
  route-level lookup.
- **`fromUri` id heuristic** (`pathParams['id'] ?? last segment`) documented and kept;
  revisit only if it proves surprising.
- **`report()`** kept and upgraded to a rich, JSON-safe diagnostic on all models (see 4.5).

## 12. Migration (v2 -> v3)

| v2 | v3 |
|----|----|
| `RouteInfo('x', mustBeAuthorized: false, isGlobalOnly: true)` | `RouteInfo('x', policy: RoutePolicy(mustBeAuthorized: false, pushGlobally: true))` |
| `RouteArgs(r, pushGlobally: true, duplicateBehavior: ...)` | `RouteArgs(r, policy: RoutePolicy(pushGlobally: true, duplicateBehavior: ...))` |
| `route.isGlobalOnly ?? false` | `route.pushGlobally` |
| `route.visibleNavBar` / `route.shouldReplaceAll` | unchanged (resolved getters) |
| `(route.isGlobalOnly ?? false) || args.effectivePushGlobally` | `args.effectivePushGlobally` |
| `DialogArgs(... super.pushGlobally ...)` | `DialogArgs(... super.policy ...)` |
| `import 'package:router_builder/models/models.dart'` | `import 'package:router_builder/router_builder.dart'` |
| `import 'route_info_helper.dart'`; `MyRoutes.x` / `RouteInfoHelper` | `import 'routes.g.dart'`; `Routes.x` / `RoutesHelper` (or pin old names via options) |
| build.yaml imports the generator path | imports `package:router_builder/builder.dart` |
| `RouteArgs(..., isIdSlug: true)` | detect via `int.tryParse(args.id)`, or a `RouteArgs` subclass |
| deep-link allowed hosts (substring) | verify list; matching is now exact-or-suffix |

Ship a "Migrating to v3" README section plus a codemod note for the mechanical folds and
the import/name swaps.

## 13. Release phasing

**v2.x bridge (additive / fixes, no breakage):**

- Expand `RoutePolicy` (new fields) + `merge`/`copyWith`/presets.
- `RouterBuilderConfig` complete defaults + `setDefaults(RoutePolicy)` + `reset`.
- Generator: runtime-derived categories (same names), include redirect routes in
  `allRoutes`, complete the policy parser; add `BuilderOptions` reading with OLD defaults.
- Deep-link host-matching fix (security; can be a patch/minor).
- `@RTConfig` (additive annotation + wiring + uniqueness check).
- Broaden `@RT` discovery.
- Keep all 2.1.0 deprecations.

**v3.0 (breaking):**

- `lib/src/` layout + single barrel + `builder.dart`.
- Flip generated defaults to `routes.g.dart` / `Routes` / `RoutesHelper`.
- Remove deprecated flat constructor params and getters; move the four extra fields fully
  into `policy`; collapse `RouteArgs` to one constructor; finalize `pushGlobally` rename.
- Enforce branch/redirect constraints; fix `RouteInfo` `props`; direct policy import.
- Conflicts fail the build by default.
- Remove `isIdSlug`; unify typedefs; drop stale `replaceAll`.

## 14. Testing strategy

No tests exist today; this is the largest risk for the refactor.

- **Precedence matrix (golden):** every field across {args} x {route} x {default} plus
  branch/redirect constraints.
- **`merge` / `RoutePolicy`:** per-field win/fill; `props` correctness.
- **`RouterBuilderConfig`:** `setDefaults` keeps completeness; `reset`; `isConfigured`.
- **Generator:** runtime getters reflect installed defaults; `deepLinkMap` topology and
  conflict-as-error; `BuilderOptions` rename file/classes; `@RT` top-level discovery;
  duplicate/non-const `@RTConfig` are build errors.
- **Deep-link matcher:** exact/suffix host accept, substring reject; redirect route
  resolution; alias and template matching.
- **Equality:** `RouteInfo` / `RouteArgs` / `RoutePolicy`.
- **`report()`:** output is `jsonEncode`-able for routes with builders/handlers and for args
  carrying a non-encodable `object` (presence flags + `toEncodable` hook).

## 15. Open questions / risks

### Open

- **O1** Default `duplicateBehavior` (`duplicate`) confirmed?
- **O2** Split `DuplicateRouteBehavior` into its own file (proposed yes).
- **O3** Branch/redirect constraint strictness: force + debug `assert` (proposed) vs hard throw.
- **O4** Keep a per-field `setDefaults({...})` wrapper alongside the `RoutePolicy` overload (proposed yes).
- **O5** Runtime getter caching: recompute per access (proposed) vs cache.

### Resolved during review

- **O6** Deep-link push-global -> dedicated `deepLinkPushGlobally` policy field (default `true`, route/global override).
- **O7** `isIdSlug` removed (per-route concern; detect from the id value).
- **O9** `@RT` discovery -> class static fields + top-level consts/finals only (no enums/mixins/extensions).
- **O8** `report()` kept and upgraded to a rich, JSON-safe diagnostic on all models (dhu `toJsonMap()`).

# CHANGELOG
## 3.0.0

Major release. See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for the full v2 -> v3
guide. Run `tool/migrate_to_v3.sh` (dry-run by default; `--write` to apply) to
make the mechanical edits - removing `isIdSlug`, `MyRoutes` -> `Routes`,
`RouteInfoHelper` -> `RoutesHelper`, and collapsing deep imports to the barrel.

### Breaking
- `RoutePolicy` is now the single home for cascading behavior (9 fields). Flat
  behavioral params/getters on `RouteInfo` and `RouteArgs` are removed; set them
  via `policy:` and read them via the resolved getters.
- `isGlobalOnly` renamed to `pushGlobally` everywhere.
- `RouteArgs` has one constructor (the private clone is gone); `isIdSlug` is
  removed (detect slug-vs-id from the value at the gate).
- Package layout moved under `lib/src/`; import only
  `package:router_builder/router_builder.dart`. Deep imports
  (`package:router_builder/models/...`) and `models/models.dart` are gone.
- `build.yaml` must import `package:router_builder/builder.dart`.
- Generated output defaults to `lib/routes.g.dart` with classes `Routes` and
  `RoutesHelper` (was `lib/route_info_helper.dart`, `MyRoutes`,
  `RouteInfoHelper`). Override via builder options if you prefer the old names.
- Deep-link host matching is now exact-or-suffix (was substring); verify your
  allowed-hosts list.
- Deep-link key conflicts now fail the build by default (`fail_on_conflict`).
- Builder typedefs unified to `(BuildContext, RouteArgs?)`.
- `RouterBuilderConfig.defaults` is read-only; use `setDefaults(RoutePolicy)`.

### Added
- `RoutePolicy.merge`/`copyWith`/`report` and `global`/`public`/`popup` presets.
- `RouterBuilderConfig` complete defaults, `reset`, `isConfigured`,
  `markConfigured`.
- Same-named resolved getters on `RouteInfo`; `effectiveX` getters on
  `RouteArgs`; branch/redirect structural constraints (force + debug assert).
- Runtime-derived generated categories (`normalRoutes`, `globalRoutes`,
  `popupRoutes`, `topLevelRoutes`, `authorizedRoutes`, `redirectRoutes`) that
  cannot drift from installed defaults; `allRoutes` now includes redirect-only
  routes.
- Configurable generator (`output`, `route_class_name`, `helper_class_name`,
  `fail_on_conflict`); `@RT` discovery now includes top-level consts/finals.
- `@RTConfig` annotation + generated `RoutesHelper.installDefaults()`.
- `deepLinkPushGlobally` policy field (default true); deep-link push-global is
  now policy-driven.
- JSON-safe `report()` on `RoutePolicy`/`RouteInfo`/`RouteArgs`.
- First test suite and a runnable `example/`.

## 2.0.4

- Relaxed `dart_helper_utils` constraint to allow compatible 6.x releases.

## 2.0.3

- Relaxed `analyzer` and `dart_style` constraints so consumers can resolve with analyzer 9 or analyzer 10.

## 2.0.2

- Updated all packages to the latest version and migrated to the latest analyzer and build runner.

## 2.0.1

- Merged 1.2.0.

## 2.0.1

- Enhanced docs.

## 2.0.0

- Updated all packages to the latest version and migrated to the latest analyzer and build runner.

## 1.2.0 - 2026-01-20

### 🚀 Major Feature: Policy-Driven Routing

This release introduces a robust, hierarchical configuration system for route behaviors, allowing precise control over authorization, duplication, and global navigation settings.

#### Added
- **RoutePolicy**: Centralized policy object for `mustBeAuthorized`, `duplicateBehavior`, `pushGlobally`, and `isPopupRoute`.
- **Global Defaults**: New `RouterBuilderConfig` to set app-wide default policies.
- **Duplicate Route Control**: Added `DuplicateRouteBehavior` to `RouteInfo` and `RouteArgs`.
- **Precedence Logic**: `RouteArgs` now resolves policies in a clear order:
  1. Args Override
  2. Args Policy
  3. Route Definition Override
  4. Route Definition Policy
  5. Global Defaults

#### Updated
- **RouteInfo**: Added `duplicateBehavior` and `policy` fields.
- **RouteArgs**: Added override fields (`duplicateBehavior`, `mustBeAuthorized`, `policy`) and logic to compute effective values.
- **Code Generator**: Updated to support `duplicateBehavior` in `@RT` annotations.

## 1.1.2 - 2025-11-07
- Renamed `replaceAll` to `shouldReplaceAll`.

## 1.1.1 - 2025-10-24
- Documented all public APIs.

## 1.1.0 - 2025-10-24
- Updated exports.

## 1.0.0 - 2025-01-24

### 🚀 Major Enhancement: Unified Deep Link System

#### Added
- **DeepLinkHandler<T>**: New generic abstract class for type-safe deep link handling
- **Enhanced RouteInfo**: Added `deepLinkHandler` parameter to all RouteInfo constructors
- **Comprehensive Deep Link Map**: Generated map now includes:
  - Route names as keys
  - First path segments as keys  
  - Deep link aliases from `deepLinkNames`
  - Build-time conflict detection with detailed error messages
- **Migration Guide**: Comprehensive guide for migrating from separate deep link registries
- **Updated Documentation**: Enhanced AI docs with deep link examples and patterns

#### Changed
- **Code Generator**: Enhanced to extract path parameters and create comprehensive key mappings
- **Deep Link Resolution**: Routes are now the single source of truth for deep links
- **Generated Helper**: `deepLinkMap` is now suitable for complete URI resolution

#### Benefits
- ✅ Single source of truth for routes and deep links
- ✅ No more RegExp patterns or manual handler registration
- ✅ Build-time validation of deep link conflicts
- ✅ Co-located deep link logic with route definitions
- ✅ Reduced boilerplate code
- ✅ Type-safe deep link handling

## 0.0.1 - Initial Release

- **INITIAL**: Initial release with basic route generation

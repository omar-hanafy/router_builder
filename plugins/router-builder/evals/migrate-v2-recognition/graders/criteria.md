Score the migration plan against the real v2 -> v3 path:

1. (20%) Mentions the shipped codemod script migrate_to_v3.sh (dry-run by
   default, --write to apply) covering the mechanical renames: isIdSlug
   removal, MyRoutes -> Routes, RouteInfoHelper -> RoutesHelper,
   route_info_helper.dart -> routes.g.dart, deep imports -> the single
   package:router_builder/router_builder.dart barrel.
2. (25%) Flat param folds with the rename: isGlobalOnly: true becomes policy:
   RoutePolicy(pushGlobally: true) (plus mustBeAuthorized inside the same
   policy); read sites drop null-coalescing (route.isGlobalOnly ?? false ->
   route.pushGlobally).
3. (15%) DialogArgs forwards super.policy instead of super.pushGlobally /
   super.isIdSlug, and isIdSlug has NO v3 replacement flag (detect from the
   value or subclass field).
4. (15%) setDefaults named args become setDefaults(const
   RoutePolicy(mustBeAuthorized: false)) or @RTConfig +
   RoutesHelper.installDefaults().
5. (15%) Regenerate with build_runner into lib/routes.g.dart (Routes /
   RoutesHelper), deleting or replacing the stale v2 generated file; consumer
   build.yaml (if present) must import package:router_builder/builder.dart.
6. (10%) Post-migration audits: deep-link host matching changed from
   substring to exact-or-suffix (audit allowedHosts), and deep-link key
   conflicts now fail the build.

Deduct for invented steps (nonexistent CLI commands, pub codemod tools) or
claiming v3 keeps the flat params as deprecated.

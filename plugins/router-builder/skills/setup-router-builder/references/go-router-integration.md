# Wiring router_builder into GoRouter (proven adapter recipe)

router_builder deliberately stops at route DATA (`RouteInfo`), per-call args
(`RouteArgs`), policy resolution, and deep-link matching. It does not create
Navigator or GoRouter routes. This recipe is distilled from two production
apps (90+ and 30+ routes) that wire the generated output into
`go_router` (v17+) with `StatefulShellRoute` tabs and an auth guard.

Adapt names to the host project. If the project already has an adapter layer,
FOLLOW IT instead of introducing this one.

## 1. RouteInfo -> GoRoute adapters

```dart
extension RouteInfoGoRouter on RouteInfo {
  /// A GoRoute for a standard route. Pass [parentRoute] for nested routes so
  /// names become `parent.child` and paths become relative segments.
  GoRoute screenRoute({RouteInfo? parentRoute, List<RouteBase> routes = const []}) {
    return GoRoute(
      name: generateName(parentRoute: parentRoute),
      path: generatePath(parentRoute: parentRoute),
      routes: routes,
      redirect: redirect == null
          ? null
          : (context, state) => redirect!(context, state.extra as RouteArgs?),
      pageBuilder: (context, state) {
        // state.extra survives pushes but is null after refresh/location-only
        // entry (including deep links); rebuild args from the URI as fallback.
        final args = state.extra is RouteArgs
            ? state.extra! as RouteArgs
            : RouteArgs.fromUri(this, state.uri);
        if (pageBuilder != null) return pageBuilder!(context, args);
        final widget = builder?.call(context, args) ?? child!;
        return MaterialPage<dynamic>(child: widget, name: name);
      },
    );
  }

  /// A StatefulShellBranch for a branch route.
  StatefulShellBranch branchRoute({List<RouteBase> nested = const []}) {
    return StatefulShellBranch(
      navigatorKey: GlobalKey<NavigatorState>(debugLabel: branchKey),
      routes: [screenRoute(routes: nested)],
    );
  }
}
```

## 2. Router assembly

```dart
GoRouter buildRouter() {
  // Install app-wide defaults BEFORE anything reads category getters.
  // Either RoutesHelper.installDefaults() (with @RTConfig) or:
  RouterBuilderConfig.setDefaults(const RoutePolicy(mustBeAuthorized: true));

  return GoRouter(
    initialLocation: Routes.splash.path,
    routes: [
      ...RoutesHelper.globalRoutes.map((r) => r.screenRoute()),
      ...RoutesHelper.normalRoutes.map((r) => r.screenRoute()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: RoutesHelper.branches[AppTab.values.first.runtimeType == AppTab ? AppTab.home : AppTab.home]!
            .values
            .map((r) => r.branchRoute())
            .toList(),
      ),
    ],
  );
}
```

Simplification for one shell enum value per shell widget: iterate
`RoutesHelper.branches.entries` and build one `StatefulShellRoute` per entry,
or use the generated per-value lists (`homeBranches`, ...). Category getters
are runtime-derived, so defaults MUST be installed before this function runs.

## 3. Pushing with RouteArgs (policy-aware)

Carry `RouteArgs` through GoRouter's `extra` and read the effective getters at
the single choke point:

```dart
Future<T?> pushArgs<T>(BuildContext context, RouteArgs args) async {
  final route = args.route;
  final router = GoRouter.of(context);
  final location = router.namedLocation(
    route.name,
    pathParameters: args.pathParams ?? const {},
    queryParameters: args.queryParams ?? const {},
  );
  if (args.effectiveShouldReplaceAll) {
    router.go(location, extra: args);
    return null;
  }
  if (_currentRouteName(router) == route.name) {
    final behavior = args.effectiveDuplicateBehavior;
    if (behavior.isDoNothing) return null;
    if (behavior.isRefresh) return router.replace<T>(location, extra: args);
  }
  return router.push<T>(location, extra: args);
}
```

`effectivePushGlobally` matters when shells are involved: pushing "globally"
means targeting the ROOT navigator (declare global routes on the root route
list, i.e. `RoutesHelper.globalRoutes`, with `parentNavigatorKey` when nesting
demands it) so the destination covers the shell instead of rendering inside
the current tab.

## 4. Auth guard with resumeTo (onEnter or redirect)

```dart
FutureOr<String?> guard(BuildContext context, GoRouterState state) {
  final args = state.extra is RouteArgs
      ? state.extra! as RouteArgs
      : _argsFromState(state);
  if (!args.effectiveMustBeAuthorized || auth.isLoggedIn) return null;
  pendingResume = args; // or persist RouteArgs via your own storage
  return Routes.login.path;
}

void onLoginSuccess(BuildContext context) {
  final next = pendingResume;
  pendingResume = null;
  if (next != null) pushArgs(context, next.cleared());
}
```

The interception idiom: capture the INTENDED `RouteArgs` as `resumeTo` (or a
stored pending intent), send the user to auth, then resume with the stored
args once the gate clears. `args.cleared()` drops `resumeTo`/`comingFrom` while
keeping navigation payload, preventing resume loops.

## 5. Deep links

Let the platform deliver the URI (GoRouter route information, app_links, or a
notifications SDK), then resolve through the package:

```dart
void onUri(Uri uri) {
  final match = RoutesHelper.resolveDeepLink(uri, allowedHosts: AppConfig.webDomains);
  if (match == null) return openNotFound(uri);
  pushArgs(rootContext, match.args);
}
```

`match.args.effectivePushGlobally` already folds the route's
`deepLinkPushGlobally`; `match.args.object` carries the original URI.

## Known integration gotchas (seen in production)

- `state.extra` is lost on browser refresh / direct-location entry: always
  keep the `RouteArgs.fromUri` fallback from step 1.
- GoRouter fires guards for the initial `/` before your `/` redirect runs;
  allow-list the root path in the guard.
- Branch navigators: Android back handling and per-tab pops need the branch
  `navigatorKey` (from `branchKey`), because the shell context cannot see the
  active branch navigator.
- `extra` cannot be threaded through `StatefulNavigationShell.goBranch`; pass
  payloads by going to a branch-root location with `extra` instead.

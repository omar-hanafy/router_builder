# Router Builder

Router Builder simplifies Flutter route management and deep linking through code generation. Define your routes once, and let the generator handle the boilerplate.

## Features

- 🚀 **Code Generation**: Automatically generates route helpers from annotations
- 🔗 **Unified Deep Links**: Routes and deep links defined in one place
- 🛡️ **Type Safety**: Strongly typed route definitions and navigation
- ⚡ **Build-time Validation**: Detects route conflicts during generation
- 🎯 **Simple API**: Clean, intuitive route definition syntax
- 🏷️ **Localized Titles**: Optional `title` callback for per-route titles that react to locale changes
- 👮 **Policy-Driven**: One `RoutePolicy` for all behavior, resolved Call -> Route -> Global
- 🗂️ **Categorized Routes**: Generated `RoutesHelper` exposes `normalRoutes`, `globalRoutes`, `popupRoutes`, `authorizedRoutes`, `redirectRoutes`, branch maps, and a `deepLinkMap`
- 🩺 **Diagnostics**: JSON-safe `report()` on `RoutePolicy`, `RouteInfo`, and `RouteArgs`

> **Upgrading from v2?** See [`MIGRATION_GUIDE.md`](MIGRATION_GUIDE.md) for the
> full v2 -> v3 guide. Key changes: one `RoutePolicy` for all behavior, a single
> `import 'package:router_builder/router_builder.dart'`, and generated `Routes` /
> `RoutesHelper` in `routes.g.dart`. The mechanical edits (removing `isIdSlug`,
> `MyRoutes` -> `Routes`, import moves) are automated by `tool/migrate_to_v3.sh`
> (dry-run by default; `--write` to apply).

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  router_builder: ^3.0.0

dev_dependencies:
  build_runner: ^2.15.0
```

### Basic Usage

1. **Define your routes** using the `@RT()` annotation:

```dart
import 'package:router_builder/router_builder.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';

class AppRoutes {
  @RT()
  static final home = RouteInfo(
    'home',
    title: (context, [args]) => context.tr.homeTitle,
    builder: (context, args) => HomeScreen(),
  );

  @RT()
  static final profile = RouteInfo(
    'profile',
    path: 'profile/:id',
    title: (context, [args]) => context.tr.profileTitle,
    builder: (context, args) => ProfileScreen(userId: args?.id),
    deepLinkNames: ['user'], // Alternative deep link: /user/:id
  );
}
```

2. **Run the generator**:

```bash
dart run build_runner build --delete-conflicting-outputs
```

3. **Use generated helpers** in your router:

```dart
import 'routes.g.dart'; // Generated file

// Access routes
final homeRoute = Routes.home;
final profileRoute = Routes.profile;

// Get route by name
final route = RoutesHelper.fromName('profile');

// Access deep link map
final deepLinkMap = RoutesHelper.deepLinkMap;
```

### RouteArgs conveniences

- `pathParams`: Map of named path params (e.g., for `post/:postId/comment/:commentId`).
- `fromUri`: Build args from a `Uri` and a `RouteInfo` template.

```dart
final args = RouteArgs.fromUri(Routes.profile, Uri.parse('/profile/123?tab=posts'));
print(args.id); // '123'
print(args.queryParams); // { 'tab': 'posts' }
print(args.pathParams); // { }
```

### Interception and resume

You can capture an intended navigation and pass it as a resume intent to another route (e.g., Auth). After the prerequisite flow completes, resume navigation using the stored intent.

```dart
// Intended destination (protected)
final intended = RouteArgs(
  Routes.profile,
  id: '123',
  queryParams: {'tab': 'posts'},
  object: UserPreview(...),
);

// Guard interception example (pseudo-code)
final isAllowed = authService.isLoggedIn;
if (!isAllowed) {
  // Navigate to auth with a resume intent
  final authArgs = RouteArgs(Routes.auth, resumeTo: intended);
  navigation.push(authArgs);
  return; // Block original navigation
}

// After successful login, resume
void onAuthSuccess(RouteArgs authArgs) {
  final next = authArgs.resumeTo;
  if (next != null) navigation.replaceAll(next);
}
```

### Hierarchical names

`RouteInfo.generateName(parentRoute: ...)` uses dot notation for names: `parent.child`.
Paths continue to use slash notation and default to `"/name"` unless overridden by `path`.

## Deep Link Integration

Routes automatically support deep linking:

```dart
@RT()
static final referral = RouteInfo(
  'referral',
  path: 'referral/:code',
  title: (context, [args]) => context.tr.referralTitle,
  builder: (context, args) => ReferralScreen(code: args?.id),
  deepLinkHandler: const ReferralDeepLinkHandler(), // Custom logic
);

// Custom handler for complex deep links
class ReferralDeepLinkHandler extends DeepLinkHandler<MyAction> {
  const ReferralDeepLinkHandler();
  
  @override
  bool canHandle(Uri uri) => true;
  
  @override
  MyAction? createAction(Uri uri, RouteInfo route) {
    final code = uri.pathSegments.last;
    return SaveReferralCodeAction(code: code);
  }
}
```

## Branch Routes (Tab Navigation)

Define routes for navigation shells:

```dart
enum NavigationTab { home, explore, profile }

@RT()
static const homeTab = RouteInfo.branch(
  'home',
  branchParentType: NavigationTab.home,
  branchIndex: 0,
  branchKey: 'home_branch',
  builder: (context, args) => HomeTab(),
  policy: RoutePolicy(isTopLevelOnly: true),
);
```

## Policy-Driven Routing

Control route behavior globally, per-route, or per-navigation call using policies.

### 1. Global Defaults

Set app-wide defaults once. The declarative way (preferred) is `@RTConfig`:
declare exactly one `const RoutePolicy` and install it at the start of `main()`:

```dart
@RTConfig()
const appRoutePolicy = RoutePolicy(
  mustBeAuthorized: true, // secure by default
  duplicateBehavior: DuplicateRouteBehavior.duplicate,
  isPopupRoute: false,
);

void main() {
  RoutesHelper.installDefaults(); // applies appRoutePolicy as global defaults
  runApp(const MyApp());
}
```

Or set them imperatively with a `RoutePolicy`:

```dart
RouterBuilderConfig.setDefaults(
  const RoutePolicy(mustBeAuthorized: true, isPopupRoute: false),
);
```

Per-route and per-call overrides win over these defaults; structural constraints
(branch/redirect) always win last.

### 2. Route Definition Overrides

Override policies for specific routes:

```dart
@RT()
static const login = RouteInfo(
  'login',
  builder: ...,
  policy: RoutePolicy(
    mustBeAuthorized: false, // Public route
    duplicateBehavior: DuplicateRouteBehavior.refresh, // Don't stack login screens
  ),
);
```

### 3. Per-Call Overrides

Override policies dynamically during navigation:

```dart
// Force a new instance even if the route usually refreshes
final loginArgs = RouteArgs(
  Routes.login,
  policy: const RoutePolicy(
    duplicateBehavior: DuplicateRouteBehavior.duplicate,
  ),
);

// Bypass auth check for specific scenarios
final debugArgs = RouteArgs(
  Routes.debug,
  policy: const RoutePolicy(mustBeAuthorized: false),
);

// Hand the args to your navigation layer (e.g. your GoRouter wiring), reading the
// resolved values - args.effectiveDuplicateBehavior, args.effectiveMustBeAuthorized,
// args.effectivePushGlobally - to decide how to navigate.
```

### Reading resolved values

There are no flat behavioral fields any more - everything lives in `RoutePolicy`.
Read the resolved (always non-null) values back through same-named getters:

- `RouteInfo`: `route.mustBeAuthorized`, `route.pushGlobally`, `route.isPopupRoute`,
  `route.visibleNavBar`, `route.isTopLevelOnly`, `route.shouldReplaceAll`,
  `route.deepLinkAllowed`, `route.deepLinkPushGlobally`, `route.duplicateBehavior`.
- `RouteArgs`: the matching `effectiveX` getters (e.g. `args.effectivePushGlobally`),
  which fold `args.policy` over `route.policy` over the global defaults.

Upgrading from v2's flat params (`isGlobalOnly`, `mustBeAuthorized`, ...)? See
[`MIGRATION_GUIDE.md`](MIGRATION_GUIDE.md).

### Policy Precedence

The effective policy is resolved by merging, highest priority first:
1. **Call policy**: `args.policy` passed during navigation.
2. **Route policy**: `policy:` defined on the `RouteInfo`.
3. **Global defaults**: from `@RTConfig` / `RouterBuilderConfig`, falling back to
   the built-in defaults.

Branch and redirect **structural constraints** are applied last and always win
(for example, a branch route can never be `pushGlobally`), with a debug assert if
a policy tries to set a conflicting value.

## Migration Guide

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for the full v2 -> v3 upgrade
(automated codemods in `tool/migrate_to_v3.sh` plus the manual steps), the older
deep-link-registry migration, and a template for future releases.

## License

This project is licensed under the MIT License.

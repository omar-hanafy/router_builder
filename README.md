# Router Builder

Router Builder simplifies Flutter route management and deep linking through code generation. Define your routes once, and let the generator handle the boilerplate.

## Features

- 🚀 **Code Generation**: Automatically generates route helpers from annotations
- 🔗 **Unified Deep Links**: Routes and deep links defined in one place
- 🛡️ **Type Safety**: Strongly typed route definitions and navigation
- ⚡ **Build-time Validation**: Detects route conflicts during generation
- 🎯 **Simple API**: Clean, intuitive route definition syntax
- 🏷️ **Localized Titles**: Optional `title` callback for per-route titles that react to locale changes
- 👮 **Policy-Driven**: Flexible control over auth and duplication logic (Global -> Route -> Call)

> **Upgrading from v2?** See the v2 -> v3 table in `MIGRATION_GUIDE.md`. Key
> changes: one `RoutePolicy` for all behavior, `import
> 'package:router_builder/router_builder.dart'` only, generated `Routes` /
> `RoutesHelper` in `routes.g.dart`.

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  router_builder: ^2.0.2

dev_dependencies:
  build_runner: ^2.10.1
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
flutter pub run build_runner build --delete-conflicting-outputs
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
  isTopLevelOnly: true,
);
```

## Policy-Driven Routing

Control route behavior globally, per-route, or per-navigation call using policies.

### 1. Global Defaults

Set default behaviors for your entire app (e.g., in your `main.dart`):

```dart
RouterBuilderConfig.setDefaults(
  mustBeAuthorized: true, // Secure by default
  duplicateBehavior: DuplicateRouteBehavior.duplicate, // Allow stacking by default
  isPopupRoute: false,
);
```

### Global defaults (`@RTConfig`)

Declare one app-wide policy and install it in `main()`:

```dart
@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false, deepLinkAllowed: true);

void main() {
  RoutesHelper.installDefaults(); // applies appRoutePolicy as global defaults
  runApp(const MyApp());
}
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
RouteArgs(
  Routes.login,
  policy: const RoutePolicy(
    duplicateBehavior: DuplicateRouteBehavior.duplicate,
  ),
).go(context);

// Bypass auth check for specific scenarios
RouteArgs(
  Routes.debug,
  policy: const RoutePolicy(mustBeAuthorized: false),
).go(context);
```

### Deprecated Root Overrides

The legacy root override fields remain available for compatibility, but are
deprecated. Prefer `policy: RoutePolicy(...)` for new code.

Deprecated route-level fields:
- `RouteInfo.mustBeAuthorized`
- `RouteInfo.pushGlobally` (resolved; set via `policy: RoutePolicy(pushGlobally: ...)`)
- `RouteInfo.isPopupRoute`
- `RouteInfo.duplicateBehavior`

Deprecated call-level fields:
- `RouteArgs.mustBeAuthorized`
- `RouteArgs.pushGlobally`
- `RouteArgs.duplicateBehavior`

### Policy Precedence

The effective policy is resolved in this order:
1. **RouteArgs Root Override**: deprecated compatibility fields passed during navigation.
2. **RouteArgs Policy**: policy object passed during navigation.
3. **Route Definition Root Override**: deprecated compatibility fields defined in `RouteInfo`.
4. **Route Definition Policy**: policy object defined in `RouteInfo`.
5. **Global Defaults**: set via `RouterBuilderConfig`.

## Migration Guide

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for migrating from separate deep link registries.

## License

This project is licensed under the MIT License.

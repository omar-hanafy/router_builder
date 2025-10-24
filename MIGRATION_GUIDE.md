# Route Generator - Deep Link Migration Guide

## Overview

The route_generator package now provides a unified system for handling both navigation and deep links. This guide explains how to migrate from the old `DeepLinkRegistry` system to the new integrated approach.

## What's Changed

### Before (Old System)
- Define routes with `@RT()` annotation
- Create separate `DeepLinkHandler` classes
- Register handlers with RegExp patterns in `action_registry.dart`
- Multiple files and registrations required

### After (New System)
- Define routes with `@RT()` annotation (same as before)
- Optionally add `deepLinkHandler` to RouteInfo for complex cases
- Simple navigation uses `deepLinkNames` list
- Everything defined in one place!

## Migration Examples

### Example 1: Simple Navigation Deep Link

**Before:**
```dart
// In product_screen.dart
@RT()
static final route = RouteInfo(
  'product',
  builder: _builder,
);

// In deep_link_handlers/product_handler.dart
class ProductDeepLinkHandler extends DeepLinkHandler {
  @override
  RegExp get pattern => RegExp(r'^/product/(\d+)');
  
  @override
  DeferredAction<dynamic>? handle(Uri uri, Match match) {
    final productId = match.group(1);
    return NavigateToRouteAction(
      route: ProductScreen.route,
      routeArgs: RouteArgs(ProductScreen.route, id: productId),
    );
  }
}

// In action_registry.dart
void _registerDeepLinkHandlers() {
  deepLinkRegistry.register(ProductDeepLinkHandler());
}
```

**After:**
```dart
// In product_screen.dart (ONLY HERE!)
@RT()
static final route = RouteInfo(
  'product',
  path: 'product/:id',
  deepLinkNames: ['item', 'p'], // Optional aliases
  builder: _builder,
);
```

That's it! The system automatically handles:
- Pattern matching from the path
- Parameter extraction (`:id`)
- Navigation action creation

### Example 2: Complex Deep Link with Custom Logic

**Before:**
```dart
// Multiple files for referral system...
class ReferralDeepLinkHandler extends DeepLinkHandler {
  @override
  RegExp get pattern => RegExp(r'^/referral/([A-Z0-9]+)');
  
  @override
  DeferredAction<dynamic>? handle(Uri uri, Match match) {
    final code = match.group(1);
    return SaveReferralCodeAction(code: code);
  }
}
```

**After:**
```dart
// In referral_screen.dart
@RT()
static final route = RouteInfo(
  'referral',
  path: 'referral/:code',
  deepLinkHandler: const ReferralDeepLinkHandler(),
  builder: _builder, // Still has UI for manual entry
);

// First, create an app-wide base handler type (in a shared file)
abstract class AppDeepLinkHandler extends DeepLinkHandler<DeferredAction<dynamic>> {}

// Then use it for all handlers
class ReferralDeepLinkHandler extends AppDeepLinkHandler {
  const ReferralDeepLinkHandler();
  
  @override
  bool canHandle(Uri uri) => true;
  
  @override
  DeferredAction<dynamic>? createAction(Uri uri, RouteInfo route) {
    final code = uri.pathSegments.last;
    return SaveReferralCodeAction(code: code);
  }
}
```

### Example 3: Multi-Action Deep Links

**Before:**
```dart
class JobDeepLinkHandler extends DeepLinkHandler {
  @override
  RegExp get pattern => RegExp(r'^/job');
  
  @override
  DeferredAction<dynamic>? handle(Uri uri, Match match) {
    final jobId = uri.pathSegments[1];
    final action = uri.queryParameters['action'];
    
    switch (action) {
      case 'apply':
        return ApplyToJobAction(
          jobId: jobId,
          coverLetter: uri.queryParameters['coverLetter'],
        );
      case 'save':
        return SaveJobAction(jobId: jobId);
      default:
        return ViewJobAction(jobId: jobId);
    }
  }
}
```

**After:**
```dart
@RT()
static final route = RouteInfo(
  'job',
  path: 'job/:id',
  deepLinkHandler: const JobDeepLinkHandler(),
  deepLinkNames: ['career', 'opportunity'], // Aliases
  builder: _builder,
);

class JobDeepLinkHandler extends AppDeepLinkHandler {
  const JobDeepLinkHandler();
  
  @override
  bool canHandle(Uri uri) => true;
  
  @override
  DeferredAction<dynamic>? createAction(Uri uri, RouteInfo route) {
    final jobId = uri.pathSegments.last;
    final action = uri.queryParameters['action'];
    
    switch (action) {
      case 'apply':
        return ApplyToJobAction(
          jobId: jobId,
          coverLetter: uri.queryParameters['coverLetter'],
        );
      case 'save':
        return SaveJobAction(jobId: jobId);
      default:
        return ViewJobAction(jobId: jobId);
    }
  }
}
```

## Deep Link Resolver

Create a simple resolver in your app to use the enhanced deep link map:

```dart
// lib/core/router_config/services/deep_link_resolver.dart
import 'package:route_generator/route_generator.dart';
import 'package:saber/core/deferred_actions/models/deferred_action.dart';
import 'package:saber/route_info_helper.dart'; // Generated file

class DeepLinkResolver {
  const DeepLinkResolver();

  DeferredAction<dynamic>? resolve(Uri uri) {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return null;

    // Try to find route by first segment
    final routeKey = pathSegments.first;
    final routeInfo = RouteInfoHelper.deepLinkMap[routeKey];
    
    if (routeInfo == null) {
      print('No route found for key: $routeKey');
      return null;
    }

    // Check if route has custom handler
    if (routeInfo.deepLinkHandler != null) {
      return routeInfo.deepLinkHandler!.createAction(uri, routeInfo);
    }

    // Default navigation action
    final routeArgs = _buildRouteArgs(routeInfo, uri);
    return NavigateToRouteAction(
      route: routeInfo,
      routeArgs: routeArgs,
    );
  }

  RouteArgs _buildRouteArgs(RouteInfo routeInfo, Uri uri) {
    String? id;
    if (uri.pathSegments.length > 1) {
      id = uri.pathSegments[1];
    }

    return RouteArgs(
      routeInfo,
      id: id,
      queryParams: uri.queryParameters,
      isFromDeeplink: true,
      pushGlobally: true,
    );
  }
}
```

## Router Integration

Update your GoRouter configuration:

```dart
// Before
onEnter: (context, currentState, nextState, router) async {
  if (nextState.uri.isOurDeepLink) {
    final action = nextState.uri.toDeepLinkAction(); // Old registry
    final handled = await ref.executeOrDefer(action, context: context);
    return !handled;
  }
  return true;
}

// After
onEnter: (context, currentState, nextState, router) async {
  if (nextState.uri.isOurDeepLink) {
    final resolver = const DeepLinkResolver();
    final action = resolver.resolve(nextState.uri);
    
    if (action != null) {
      final result = await ref.executeOrDefer(action, context: context);
      return !result.isSuccess && !result.isDeferred;
    }
  }
  return true;
}
```

## Key Benefits

1. **Single Source of Truth**: Routes and deep links defined together
2. **Less Code**: Remove entire DeepLinkRegistry subsystem
3. **Type Safety**: No RegExp strings to maintain
4. **Build-Time Validation**: Conflicts detected during code generation
5. **Better Organization**: Handlers live with their routes

## Conflict Resolution

If you see a conflict error during build:

```
[SEVERE] Deep Link Key Conflict Detected!
  Key: 'profile'
  Used by: UserScreen.route, ProfileScreen.route
```

Resolution options:
1. Change one route's name
2. Use a different path
3. Use unique deepLinkNames

## Advanced Features

### Conditional Handling

```dart
class PremiumContentHandler extends DeepLinkHandler {
  const PremiumContentHandler();
  
  @override
  bool canHandle(Uri uri) {
    // Skip handling for specific conditions
    return uri.queryParameters['preview'] != 'true';
  }
  
  @override
  DeferredAction<dynamic>? createAction(Uri uri, RouteInfo route) {
    return ViewPremiumContentAction(
      contentId: uri.pathSegments.last,
      requiredConditions: {AppConditions.hasSubscription},
    );
  }
}
```

### Path Parameter Patterns

The system automatically extracts parameters from paths:
- `profile/:id` → Extracts `id` parameter
- `shop/:category/:productId` → Extracts both parameters
- `search/*query` → Captures remaining path

## Cleanup Checklist

After migration, delete:
- [ ] `deep_link_registry.dart`
- [ ] All `DeepLinkHandler` implementations (except new ones)
- [ ] Handler registrations in `action_registry.dart`
- [ ] `toDeepLinkAction()` extension on Uri

## Need Help?

- Check generated `route_info_helper.dart` for the `deepLinkMap`
- Use `flutter pub run build_runner build` to regenerate
- Conflicts are reported during build with clear guidance
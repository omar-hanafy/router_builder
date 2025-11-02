import 'package:flutter/foundation.dart';
import 'package:router_builder/models/route_info.dart';

/// Abstract base class for handling deep links with custom logic.
///
/// Extend this class to create custom deep link handlers that can perform
/// complex operations beyond simple navigation, such as:
/// - Saving referral codes
/// - Processing promotional links
/// - Handling authentication flows
/// - Executing business logic before navigation
///
/// Example:
/// ```dart
/// // In your app, create a base type:
/// abstract class AppDeepLinkHandler extends DeepLinkHandler<DeferredAction<dynamic>> {}
///
/// // Then use it for all handlers:
/// class ReferralDeepLinkHandler extends AppDeepLinkHandler {
///   const ReferralDeepLinkHandler();
///
///   @override
///   bool canHandle(Uri uri) => true; // RouteInfo already filtered by path
///
///   @override
///   DeferredAction<dynamic>? createAction(Uri uri, RouteInfo route) {
///     final code = uri.pathSegments.last;
///     return SaveReferralCodeAction(code: code);
///   }
/// }
/// ```
@optionalTypeArgs
abstract class DeepLinkHandler<T extends Object?> {
  /// Creates a constant deep link handler.
  const DeepLinkHandler();

  /// Determines if this handler can process the given URI.
  ///
  /// This method is called after the route has been matched, so you can
  /// assume the URI matches the route's path pattern. Return `false` if
  /// you want to skip handling for specific conditions.
  ///
  /// [uri] The incoming deep link URI to evaluate.
  bool canHandle(Uri uri);

  /// Creates an action for processing the deep link.
  ///
  /// This method should parse the URI and create an appropriate action
  /// that will be processed by your app's action system. The action can:
  /// - Navigate to a screen
  /// - Save data locally
  /// - Make API calls
  /// - Combine multiple operations
  ///
  /// Return `null` if the URI cannot be handled (e.g., missing required parameters).
  ///
  /// [uri] The incoming deep link URI to process.
  /// [route] The matched RouteInfo that contains this handler.
  ///
  /// The generic type T allows for type-safe action creation. In your app,
  /// you can create a base handler type like:
  /// ```dart
  /// abstract class AppDeepLinkHandler extends DeepLinkHandler<DeferredAction<dynamic>> {}
  /// ```
  T? createAction(Uri uri, RouteInfo route);
}

/// Convenience utilities for working with path segments when handling deep links.
extension DeepLinkHandlerUriExtension on Uri {
  /// Helper: extract the last segment as a generic id.
  /// Useful for simple '/.../:id' patterns.
  String? extractIdFromSegments() {
    final segments = pathSegments;
    if (segments.isEmpty) return null;
    return segments.last;
  }

  /// Extract named path parameters from a route template.
  ///
  /// Example:
  ///   template: 'post/:postId/comment/:commentId'
  ///   uri:      '/post/42/comment/7?sort=top'
  ///   returns:  { 'postId': '42', 'commentId': '7' }
  Map<String, String> extractPathParamsByTemplate(String template) {
    final uriSegments = pathSegments;
    final templateSegments = template
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    final params = <String, String>{};
    final len =
        (uriSegments.length < templateSegments.length)
            ? uriSegments.length
            : templateSegments.length;

    for (var i = 0; i < len; i++) {
      final t = templateSegments[i];
      final u = uriSegments[i];
      if (t.startsWith(':') && t.length > 1) {
        params[t.substring(1)] = u;
      }
    }
    return params;
  }
}

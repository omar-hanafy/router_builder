import 'package:equatable/equatable.dart';
import 'package:router_builder/models/route_info.dart';

/// Encapsulates arguments for navigation actions.
///
/// RouteArgs combines the target route with navigation parameters
/// such as IDs, query parameters, and behavioral flags.
class RouteArgs extends Equatable {
  const RouteArgs(
    this.route, {
    this.id,
    this.queryParams,
    this.pathParams,
    this.object,
    this.resumeTo,
    this.comingFrom,
    this.isFromDeeplink = false,
    this.pushGlobally = false,
    this.duplicateBehavior = DuplicateRouteBehavior.duplicate,
    this.isIdSlug = false,
  });

  /// Build RouteArgs from a Uri and a RouteInfo with a path template.
  /// - Extracts named path parameters from the template
  /// - Uses 'id' param if present as [id]
  /// - Copies query parameters
  factory RouteArgs.fromUri(RouteInfo route, Uri uri) {
    // Derive a template that has no leading '/'
    final template =
        route.path.startsWith('/') ? route.path.substring(1) : route.path;
    // Inline extraction to avoid cross-layer imports
    Map<String, String> extract(String template) {
      final uriSegments = uri.pathSegments;
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

    final pathParams = extract(template);
    final qp = <String, String>{}..addAll(uri.queryParameters);
    return RouteArgs(
      route,
      id:
          pathParams['id'] ??
          (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null),
      pathParams: pathParams.isEmpty ? null : pathParams,
      queryParams: qp.isEmpty ? null : qp,
      isFromDeeplink: true,
    );
  }

  /// The target route to navigate to.
  final RouteInfo route;

  /// Optional ID parameter (e.g., from path '/users/:id').
  final String? id;

  /// Named path parameters extracted from the route's path template.
  /// Example for template 'post/:postId/comment/:commentId':
  /// { 'postId': '42', 'commentId': '7' }
  final Map<String, String>? pathParams;

  /// Whether this navigation originated from a deep link.
  final bool isFromDeeplink;

  /// How to handle navigation when the route already exists in the stack.
  final DuplicateRouteBehavior duplicateBehavior;

  /// Whether the ID is a user-friendly slug vs numeric ID.
  final bool isIdSlug;

  /// Whether to use the root navigator instead of nested navigators.
  final bool pushGlobally;

  /// Arbitrary data to pass to the route.
  final Object? object;

  /// Optional resume intent to execute after this route completes
  /// a prerequisite flow (e.g., authentication).
  ///
  /// Example: if a guard blocks navigation to a protected route, you can
  /// navigate to the Auth route with `resumeTo` set to the original intent.
  /// After successful login, the app can resume navigation using this.
  final RouteArgs? resumeTo;

  /// The originating route for this navigation, if applicable.
  ///
  /// Useful for analytics, conditional behavior, or back navigation logic
  /// that depends on the previous route context.
  final RouteArgs? comingFrom;

  /// Query parameters from the URI.
  final Map<String, String>? queryParams;

  /// Create a copy with overridden fields.
  RouteArgs copyWith({
    RouteInfo? route,
    String? id,
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    Object? object,
    RouteArgs? resumeTo,
    RouteArgs? comingFrom,
    bool? isFromDeeplink,
    bool? pushGlobally,
    DuplicateRouteBehavior? duplicateBehavior,
    bool? isIdSlug,
  }) => RouteArgs(
    route ?? this.route,
    id: id ?? this.id,
    pathParams: pathParams ?? this.pathParams,
    queryParams: queryParams ?? this.queryParams,
    object: object ?? this.object,
    resumeTo: resumeTo ?? this.resumeTo,
    comingFrom: comingFrom ?? this.comingFrom,
    isFromDeeplink: isFromDeeplink ?? this.isFromDeeplink,
    pushGlobally: pushGlobally ?? this.pushGlobally,
    duplicateBehavior: duplicateBehavior ?? this.duplicateBehavior,
    isIdSlug: isIdSlug ?? this.isIdSlug,
  );

  RouteArgs cleared() => RouteArgs(
    route,
    id: id,
    pathParams: pathParams,
    queryParams: queryParams,
    object: object,
    isFromDeeplink: isFromDeeplink,
    pushGlobally: pushGlobally,
    duplicateBehavior: duplicateBehavior,
    isIdSlug: isIdSlug,
  );

  @override
  List<Object?> get props => [
    route,
    id,
    pathParams,
    queryParams,
    object,
    resumeTo,
    comingFrom,
    isFromDeeplink,
    pushGlobally,
    duplicateBehavior,
    isIdSlug,
  ];
}

/// Defines behavior when navigating to a route already in the stack.
enum DuplicateRouteBehavior {
  /// Push a new instance of the route onto the stack.
  duplicate,

  /// Replace the current route with updated parameters instead of pushing a new instance.
  refresh,

  /// Cancel the navigation entirely.
  doNothing;

  bool get isDuplicate => this == duplicate;

  bool get isRefresh => this == refresh;

  bool get isDoNothing => this == doNothing;
}

extension DuplicateRouteBehaviorEx on DuplicateRouteBehavior? {
  bool get isDuplicate => this?.isDuplicate ?? false;

  bool get isRefresh => this?.isRefresh ?? false;

  bool get isDoNothing => this?.isDoNothing ?? false;
}

extension RouteArgsX on RouteArgs? {
  bool get requiresAuth => this?.route.mustBeAuthorized ?? false;
}

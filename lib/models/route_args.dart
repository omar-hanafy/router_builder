import 'package:equatable/equatable.dart';
import 'package:router_builder/models/route_info.dart';
import 'package:router_builder/models/route_policy.dart';
import 'package:router_builder/router_config.dart';

/// Encapsulates arguments for navigation actions.
///
/// RouteArgs combines the target route with navigation parameters
/// such as IDs, query parameters, and behavioral flags.
class RouteArgs extends Equatable {
  /// Creates navigation arguments for the provided [route].
  const RouteArgs(
    this.route, {
    this.id,
    this.queryParams,
    this.pathParams,
    this.object,
    this.resumeTo,
    this.comingFrom,
    this.isFromDeeplink = false,
    this.pushGlobally,
    this.duplicateBehavior,
    this.isIdSlug = false,
    this.mustBeAuthorized,
    this.policy,
  });

  /// Build RouteArgs from a Uri and a RouteInfo with a path template.
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
  final Map<String, String>? pathParams;

  /// Whether this navigation originated from a deep link.
  final bool isFromDeeplink;

  /// How to handle navigation when the route already exists in the stack.
  final DuplicateRouteBehavior? duplicateBehavior;

  /// Whether the ID is a user-friendly slug vs numeric ID.
  final bool isIdSlug;

  /// Whether to use the root navigator instead of nested navigators.
  final bool? pushGlobally;

  /// Arbitrary data to pass to the route.
  final Object? object;

  /// Optional resume intent.
  final RouteArgs? resumeTo;

  /// The originating route for this navigation.
  final RouteArgs? comingFrom;

  /// Query parameters from the URI.
  final Map<String, String>? queryParams;

  /// Authorization override for this navigation.
  final bool? mustBeAuthorized;

  /// Policy override for this navigation.
  final RoutePolicy? policy;

  // --------------------------------------------------------------------------
  // EFFECTIVE POLICY RESOLUTION
  // --------------------------------------------------------------------------

  /// Resolves the effective authorization requirement.
  ///
  /// Precedence:
  /// 1. Args [mustBeAuthorized]
  /// 2. Args [policy]
  /// 3. Route [mustBeAuthorized]
  /// 4. Route [policy]
  /// 5. Global defaults
  bool get effectiveMustBeAuthorized {
    return mustBeAuthorized ??
        policy?.mustBeAuthorized ??
        route.mustBeAuthorized ??
        route.policy?.mustBeAuthorized ??
        RouterBuilderConfig.defaults.mustBeAuthorized ??
        true;
  }

  /// Resolves the effective duplicate behavior.
  DuplicateRouteBehavior get effectiveDuplicateBehavior {
    return duplicateBehavior ??
        policy?.duplicateBehavior ??
        route.duplicateBehavior ??
        route.policy?.duplicateBehavior ??
        RouterBuilderConfig.defaults.duplicateBehavior ??
        DuplicateRouteBehavior.duplicate;
  }

  /// Resolves the effective global push setting.
  bool get effectivePushGlobally {
    return pushGlobally ??
        policy?.pushGlobally ??
        route.isGlobalOnly ??
        route.policy?.pushGlobally ??
        RouterBuilderConfig.defaults.pushGlobally ??
        false;
  }

  /// Resolves the effective popup route setting.
  bool get effectiveIsPopupRoute {
    return policy?.isPopupRoute ??
        route.isPopupRoute ??
        route.policy?.isPopupRoute ??
        RouterBuilderConfig.defaults.isPopupRoute ??
        false;
  }

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
    bool? mustBeAuthorized,
    RoutePolicy? policy,
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
    mustBeAuthorized: mustBeAuthorized ?? this.mustBeAuthorized,
    policy: policy ?? this.policy,
  );

  /// Returns a copy with navigation context preserved but flow metadata cleared.
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
    mustBeAuthorized: mustBeAuthorized,
    policy: policy,
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
    mustBeAuthorized,
    policy,
  ];
}

/// Convenience helpers for nullable [RouteArgs].
extension RouteArgsX on RouteArgs? {
  /// Returns `true` when the underlying route requires authorization.
  bool get requiresAuth => this?.effectiveMustBeAuthorized ?? false;
}

import 'package:equatable/equatable.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';
import 'package:router_builder/src/models/route_info.dart';
import 'package:router_builder/src/models/route_policy.dart';
import 'package:router_builder/src/router_config.dart';

export 'package:router_builder/src/models/route_policy.dart';

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
    @Deprecated('Use policy: RoutePolicy(pushGlobally: ...) instead.')
    bool? pushGlobally,
    @Deprecated('Use policy: RoutePolicy(duplicateBehavior: ...) instead.')
    DuplicateRouteBehavior? duplicateBehavior,
    this.isIdSlug = false,
    @Deprecated('Use policy: RoutePolicy(mustBeAuthorized: ...) instead.')
    bool? mustBeAuthorized,
    this.policy,
  }) : _pushGlobally = pushGlobally,
       _duplicateBehavior = duplicateBehavior,
       _mustBeAuthorized = mustBeAuthorized;

  const RouteArgs._(
    this.route, {
    this.id,
    this.queryParams,
    this.pathParams,
    this.object,
    this.resumeTo,
    this.comingFrom,
    this.isFromDeeplink = false,
    bool? pushGlobally,
    DuplicateRouteBehavior? duplicateBehavior,
    this.isIdSlug = false,
    bool? mustBeAuthorized,
    this.policy,
  }) : _pushGlobally = pushGlobally,
       _duplicateBehavior = duplicateBehavior,
       _mustBeAuthorized = mustBeAuthorized;

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
    return RouteArgs._(
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

  final DuplicateRouteBehavior? _duplicateBehavior;

  /// How to handle navigation when the route already exists in the stack.
  @Deprecated('Use policy.duplicateBehavior instead.')
  DuplicateRouteBehavior? get duplicateBehavior => _duplicateBehavior;

  /// Whether the ID is a user-friendly slug vs numeric ID.
  final bool isIdSlug;

  final bool? _pushGlobally;

  /// Whether to use the root navigator instead of nested navigators.
  @Deprecated('Use policy.pushGlobally instead.')
  bool? get pushGlobally => _pushGlobally;

  /// Arbitrary data to pass to the route.
  final Object? object;

  /// Optional resume intent.
  final RouteArgs? resumeTo;

  /// The originating route for this navigation.
  final RouteArgs? comingFrom;

  /// Query parameters from the URI.
  final Map<String, String>? queryParams;

  final bool? _mustBeAuthorized;

  /// Authorization override for this navigation.
  @Deprecated('Use policy.mustBeAuthorized instead.')
  bool? get mustBeAuthorized => _mustBeAuthorized;

  /// Policy override for this navigation.
  final RoutePolicy? policy;

  /// Navigation-level policy with deprecated root overrides applied over [policy].
  ///
  /// This does not include route-level policy or global defaults.
  RoutePolicy get localPolicy => RoutePolicy(
    mustBeAuthorized: _mustBeAuthorized ?? policy?.mustBeAuthorized,
    duplicateBehavior: _duplicateBehavior ?? policy?.duplicateBehavior,
    pushGlobally: _pushGlobally ?? policy?.pushGlobally,
    isPopupRoute: policy?.isPopupRoute,
  );

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
    return localPolicy.mustBeAuthorized ??
        route.localPolicy.mustBeAuthorized ??
        RouterBuilderConfig.defaults.mustBeAuthorized ??
        true;
  }

  /// Resolves the effective duplicate behavior.
  DuplicateRouteBehavior get effectiveDuplicateBehavior {
    return localPolicy.duplicateBehavior ??
        route.localPolicy.duplicateBehavior ??
        RouterBuilderConfig.defaults.duplicateBehavior ??
        DuplicateRouteBehavior.duplicate;
  }

  /// Resolves the effective global push setting.
  bool get effectivePushGlobally {
    return localPolicy.pushGlobally ??
        route.localPolicy.pushGlobally ??
        RouterBuilderConfig.defaults.pushGlobally ??
        false;
  }

  /// Resolves the effective popup route setting.
  bool get effectiveIsPopupRoute {
    return localPolicy.isPopupRoute ??
        route.localPolicy.isPopupRoute ??
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
    @Deprecated('Use policy: RoutePolicy(pushGlobally: ...) instead.')
    bool? pushGlobally,
    @Deprecated('Use policy: RoutePolicy(duplicateBehavior: ...) instead.')
    DuplicateRouteBehavior? duplicateBehavior,
    bool? isIdSlug,
    @Deprecated('Use policy: RoutePolicy(mustBeAuthorized: ...) instead.')
    bool? mustBeAuthorized,
    RoutePolicy? policy,
  }) => RouteArgs._(
    route ?? this.route,
    id: id ?? this.id,
    pathParams: pathParams ?? this.pathParams,
    queryParams: queryParams ?? this.queryParams,
    object: object ?? this.object,
    resumeTo: resumeTo ?? this.resumeTo,
    comingFrom: comingFrom ?? this.comingFrom,
    isFromDeeplink: isFromDeeplink ?? this.isFromDeeplink,
    pushGlobally: pushGlobally ?? _pushGlobally,
    duplicateBehavior: duplicateBehavior ?? _duplicateBehavior,
    isIdSlug: isIdSlug ?? this.isIdSlug,
    mustBeAuthorized: mustBeAuthorized ?? _mustBeAuthorized,
    policy: policy ?? this.policy,
  );

  /// Returns a copy with navigation context preserved but flow metadata cleared.
  RouteArgs cleared() => RouteArgs._(
    route,
    id: id,
    pathParams: pathParams,
    queryParams: queryParams,
    object: object,
    isFromDeeplink: isFromDeeplink,
    pushGlobally: _pushGlobally,
    duplicateBehavior: _duplicateBehavior,
    isIdSlug: isIdSlug,
    mustBeAuthorized: _mustBeAuthorized,
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
    _pushGlobally,
    _duplicateBehavior,
    isIdSlug,
    _mustBeAuthorized,
    policy,
  ];
}

/// Convenience helpers for nullable [RouteArgs].
extension RouteArgsX on RouteArgs? {
  /// Returns `true` when the underlying route requires authorization.
  bool get requiresAuth => this?.effectiveMustBeAuthorized ?? false;
}

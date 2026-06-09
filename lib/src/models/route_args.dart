import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';
import 'package:router_builder/src/models/route_info.dart';
import 'package:router_builder/src/models/route_policy.dart';
import 'package:router_builder/src/router_config.dart';

/// Per-call navigation arguments for a [RouteInfo].
///
/// Carries the target route plus optional id/params/object and a per-call
/// [policy] override. Resolution folds `args.policy` over `route.policy` over
/// [RouterBuilderConfig.defaults], then applies structural constraints; read
/// the result through the `effectiveX` getters. Subclass via super-parameters
/// (e.g. dialog/sheet args) - the constructor shape is an extensibility
/// contract.
class RouteArgs extends Equatable {
  /// Creates navigation arguments for [route].
  const RouteArgs(
    this.route, {
    this.id,
    this.queryParams,
    this.pathParams,
    this.object,
    this.resumeTo,
    this.comingFrom,
    this.isFromDeeplink = false,
    this.policy,
  });

  /// Builds args from a [uri] using [route]'s path template.
  factory RouteArgs.fromUri(RouteInfo route, Uri uri) {
    final template =
        route.path.startsWith('/') ? route.path.substring(1) : route.path;

    Map<String, String> extract(String template) {
      final uriSegments = uri.pathSegments;
      final templateSegments = template
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      final params = <String, String>{};
      final len =
          uriSegments.length < templateSegments.length
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

  /// Optional id parameter (e.g. from path `/users/:id`).
  final String? id;

  /// Named path parameters extracted from the route's path template.
  final Map<String, String>? pathParams;

  /// Query parameters from the URI.
  final Map<String, String>? queryParams;

  /// Arbitrary payload to pass to the route.
  final Object? object;

  /// Optional resume intent.
  final RouteArgs? resumeTo;

  /// The originating navigation, if any.
  final RouteArgs? comingFrom;

  /// Whether this navigation originated from a deep link.
  final bool isFromDeeplink;

  /// Per-call policy override.
  final RoutePolicy? policy;

  /// The fully resolved, constrained policy for this navigation call.
  ///
  /// Precedence: `args.policy` -> `route.policy` -> defaults; structural
  /// constraints applied last. All nine fields are non-null.
  RoutePolicy get effectivePolicy => route
      .constrain((policy ?? const RoutePolicy()).merge(route.policy))
      .merge(RouterBuilderConfig.defaults);

  /// Resolved authentication requirement.
  bool get effectiveMustBeAuthorized => effectivePolicy.mustBeAuthorized!;

  /// Resolved duplicate behavior.
  DuplicateRouteBehavior get effectiveDuplicateBehavior =>
      effectivePolicy.duplicateBehavior!;

  /// Resolved root-navigator push setting.
  bool get effectivePushGlobally => effectivePolicy.pushGlobally!;

  /// Resolved popup setting.
  bool get effectiveIsPopupRoute => effectivePolicy.isPopupRoute!;

  /// Resolved nav-bar visibility.
  bool get effectiveVisibleNavBar => effectivePolicy.visibleNavBar!;

  /// Resolved top-level-only setting.
  bool get effectiveIsTopLevelOnly => effectivePolicy.isTopLevelOnly!;

  /// Resolved replace-all setting.
  bool get effectiveShouldReplaceAll => effectivePolicy.shouldReplaceAll!;

  /// Resolved deep-link allowance.
  bool get effectiveDeepLinkAllowed => effectivePolicy.deepLinkAllowed!;

  /// Resolved deep-link push-global setting.
  bool get effectiveDeepLinkPushGlobally =>
      effectivePolicy.deepLinkPushGlobally!;

  /// Returns a copy with the provided fields overridden.
  RouteArgs copyWith({
    RouteInfo? route,
    String? id,
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    Object? object,
    RouteArgs? resumeTo,
    RouteArgs? comingFrom,
    bool? isFromDeeplink,
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
    policy: policy,
  );

  /// A rich, JSON-safe diagnostic snapshot (effective policy + shallow route /
  /// resumeTo / comingFrom summaries to avoid cycles).
  Map<String, dynamic> report({
    JsonOptions options = const JsonOptions(),
    Object? Function(dynamic)? toEncodable,
  }) => _rawReport().toJsonMap(options: options, toEncodable: toEncodable);

  Map<String, dynamic> _rawReport() => {
    'route': {'name': route.name, 'path': route.path},
    'id': id,
    'pathParams': pathParams,
    'queryParams': queryParams,
    'object': object,
    'isFromDeeplink': isFromDeeplink,
    'resumeTo':
        resumeTo == null
            ? null
            : {'name': resumeTo!.route.name, 'id': resumeTo!.id},
    'comingFrom':
        comingFrom == null
            ? null
            : {'name': comingFrom!.route.name, 'id': comingFrom!.id},
    'effectivePolicy': effectivePolicy.toMap(),
  };

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
    policy,
  ];
}

/// Convenience helpers for nullable [RouteArgs].
extension RouteArgsX on RouteArgs? {
  /// Whether the underlying route requires authorization.
  bool get requiresAuth => this?.effectiveMustBeAuthorized ?? false;
}

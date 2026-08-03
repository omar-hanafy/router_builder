import 'dart:async';

import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:router_builder/src/handlers/deep_link_handler.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';
import 'package:router_builder/src/models/route_args.dart';
import 'package:router_builder/src/models/route_policy.dart';
import 'package:router_builder/src/router_config.dart';

/// Builds a localized title for a route.
typedef ScreenTitleBuilder =
    String Function(BuildContext context, RouteArgs? args);

/// Builds the widget for a route.
typedef ScreenWidgetBuilder =
    Widget Function(BuildContext context, RouteArgs? args);

/// Builds a custom [Page] for a route, enabling tailored transitions.
typedef ScreenPageBuilder =
    Page<dynamic> Function(BuildContext context, RouteArgs? args);

/// The signature of the redirect callback.
typedef RouterRedirect =
    FutureOr<String?> Function(BuildContext context, RouteArgs? args);

/// Declarative configuration for a navigation route.
///
/// Behavioral settings live in [policy]; read them back through the same-named
/// resolved getters (e.g. [pushGlobally], [mustBeAuthorized]), which fold
/// `route.policy` over [RouterBuilderConfig.defaults] and apply structural
/// constraints. Annotate static or top-level `RouteInfo` values with `@RT` to
/// include them in code generation.
class RouteInfo extends Equatable {
  /// Creates a standard navigation route.
  ///
  /// Exactly one of [builder], [child], or [pageBuilder] must be provided.
  const RouteInfo(
    this.name, {
    this.title,
    this.builder,
    this.child,
    this.pageBuilder,
    this.redirect,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.policy,
    String? path,
  }) : _path = path,
       isBranch = false,
       branchIndex = null,
       branchKey = null,
       branchParentType = null,
       forRedirectionOnly = false,
       assert(
         (builder != null && child == null && pageBuilder == null) ||
             (builder == null && child != null && pageBuilder == null) ||
             (builder == null && child == null && pageBuilder != null),
         'Exactly one of builder, child, or pageBuilder must be provided.',
       );

  /// Creates a route that only performs redirection (no UI of its own).
  const RouteInfo.redirect(
    this.name, {
    required this.redirect,
    this.title,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.policy,
    String? path,
  }) : _path = path,
       builder = null,
       child = null,
       pageBuilder = null,
       isBranch = false,
       branchIndex = null,
       branchKey = null,
       branchParentType = null,
       forRedirectionOnly = true;

  /// Creates a route that belongs to a navigation shell (e.g. a tab).
  ///
  /// Branches are grouped by [branchParentType] and ordered by [branchIndex];
  /// [branchKey] names the branch's navigator key.
  const RouteInfo.branch(
    this.name, {
    required this.branchIndex,
    required this.branchKey,
    required this.branchParentType,
    this.title,
    this.child,
    this.builder,
    this.pageBuilder,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.policy,
    String? path,
  }) : _path = path,
       isBranch = true,
       redirect = null,
       forRedirectionOnly = false,
       assert(
         (builder != null && child == null && pageBuilder == null) ||
             (builder == null && child != null && pageBuilder == null) ||
             (builder == null && child == null && pageBuilder != null),
         'Exactly one of builder, child, or pageBuilder must be provided.',
       );

  /// Unique identifier for this route.
  final String name;

  /// Whether this route is used solely for redirection.
  final bool forRedirectionOnly;

  /// Whether this route belongs to a navigation shell.
  final bool isBranch;

  /// Position of this branch within its shell (branch routes only).
  final int? branchIndex;

  /// Navigator key identifier for branch routes.
  final String? branchKey;

  /// Enum discriminator used to group branch routes.
  final Enum? branchParentType;

  /// Localized title provider for this route.
  final ScreenTitleBuilder? title;

  /// Builds the widget for this route when navigation occurs.
  final ScreenWidgetBuilder? builder;

  /// Static widget instance for routes that do not need a builder.
  final Widget? child;

  /// Builds a custom [Page] for this route.
  final ScreenPageBuilder? pageBuilder;

  /// Redirect handler for conditional navigation.
  final RouterRedirect? redirect;

  /// Alternative names for deep-link matching.
  final List<String> deepLinkNames;

  /// Handler for complex deep-link logic beyond navigation.
  final DeepLinkHandler<dynamic>? deepLinkHandler;

  /// Comprehensive behavioral policy for this route.
  final RoutePolicy? policy;

  /// Backing field for [path]; defaults to `/$name` when null.
  final String? _path;

  /// The route's path segment (defaults to `/$name`).
  String get path => _path ?? '/$name';

  /// Applies branch/redirect structural constraints to [policy].
  ///
  /// Branches force `pushGlobally`/`isPopupRoute`/`deepLinkPushGlobally` false;
  /// redirect-only routes force `isPopupRoute`/`visibleNavBar`/`shouldReplaceAll`
  /// false. In debug builds, an assert fires if [policy] tries to set a forced
  /// field to a conflicting value.
  RoutePolicy constrain(RoutePolicy policy) {
    if (isBranch) {
      assert(
        policy.pushGlobally != true &&
            policy.isPopupRoute != true &&
            policy.deepLinkPushGlobally != true,
        'Branch route "$name": pushGlobally/isPopupRoute/deepLinkPushGlobally '
        'are forced false and cannot be set via policy.',
      );
      return policy.copyWith(
        pushGlobally: false,
        isPopupRoute: false,
        deepLinkPushGlobally: false,
      );
    }
    if (forRedirectionOnly) {
      assert(
        policy.isPopupRoute != true &&
            policy.visibleNavBar != true &&
            policy.shouldReplaceAll != true,
        'Redirect route "$name": isPopupRoute/visibleNavBar/shouldReplaceAll '
        'are forced false and cannot be set via policy.',
      );
      return policy.copyWith(
        isPopupRoute: false,
        visibleNavBar: false,
        shouldReplaceAll: false,
      );
    }
    return policy;
  }

  /// This route's policy folded over global defaults, then constrained.
  ///
  /// All nine fields are non-null. Does not include per-call (`args`) overrides.
  RoutePolicy get resolvedPolicy => constrain(
    policy ?? const RoutePolicy(),
  ).merge(RouterBuilderConfig.defaults);

  /// Whether authentication is required (resolved).
  bool get mustBeAuthorized => resolvedPolicy.mustBeAuthorized!;

  /// How duplicates are handled (resolved).
  DuplicateRouteBehavior get duplicateBehavior =>
      resolvedPolicy.duplicateBehavior!;

  /// Whether this route pushes on the root navigator (resolved).
  bool get pushGlobally => resolvedPolicy.pushGlobally!;

  /// Whether this route is a popup (resolved).
  bool get isPopupRoute => resolvedPolicy.isPopupRoute!;

  /// Whether the primary nav UI stays visible (resolved).
  bool get visibleNavBar => resolvedPolicy.visibleNavBar!;

  /// Whether this route stays top-level in its navigator (resolved).
  bool get isTopLevelOnly => resolvedPolicy.isTopLevelOnly!;

  /// Whether navigation replaces the whole stack (resolved).
  bool get shouldReplaceAll => resolvedPolicy.shouldReplaceAll!;

  /// Whether this route is reachable via deep links (resolved).
  bool get deepLinkAllowed => resolvedPolicy.deepLinkAllowed!;

  /// Whether a deep link to this route pushes globally (resolved).
  bool get deepLinkPushGlobally => resolvedPolicy.deepLinkPushGlobally!;

  /// Builds a hierarchical name optionally scoped under [parentRoute].
  String generateName({RouteInfo? parentRoute}) =>
      parentRoute != null ? '${parentRoute.name}.$name' : name;

  /// Builds a hierarchical path optionally scoped under [parentRoute].
  ///
  /// Top level: the declared [path] (e.g. `/account-settings`).
  /// Nested under [parentRoute]: the route [name] (e.g. `app_settings`).
  ///
  /// A nested segment is relative and identifies the route *inside the tree*,
  /// so it deliberately tracks [name] rather than [path]: the public URL in
  /// [path] can change without moving the route within its shell branch.
  ///
  /// Do not re-derive this rule at call sites - use [location] instead, which
  /// is built on top of this method so navigation and registration cannot
  /// disagree.
  String generatePath({RouteInfo? parentRoute}) =>
      parentRoute != null ? name : path;

  /// The location string to hand to the router when navigating to this route.
  ///
  /// This is the only supported way to build a location. It reuses
  /// [generatePath] - the same method the router tree is registered with - so a
  /// location produced here always resolves against the registered tree.
  ///
  /// Pass [parentRoute] when pushing inside a shell branch (the branch's root
  /// route); leave it null for a root-navigator/global push, which uses the
  /// route's own top-level [path].
  ///
  /// Path parameters are filled from [pathParams], falling back to [id] for
  /// `:id`. In debug builds a missing parameter trips an assert; in release the
  /// template is returned unfilled so the router surfaces its error page
  /// instead of the caller throwing inside a tap handler.
  String location({
    RouteInfo? parentRoute,
    String? id,
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
  }) {
    final segment = _hydratePath(
      generatePath(parentRoute: parentRoute),
      id: id,
      pathParams: pathParams,
    );
    final fullPath =
        parentRoute == null
            ? segment
            : _joinPaths(parentRoute.generatePath(), segment);
    return Uri(
      path: fullPath,
      queryParameters:
          (queryParams == null || queryParams.isEmpty) ? null : queryParams,
    ).toString();
  }

  /// [location] driven by an existing [RouteArgs].
  ///
  /// Prefer this at navigation call sites: it threads `id`, `pathParams` and
  /// `queryParams` through in one step, so a caller cannot forget one.
  String locationForArgs(RouteArgs args, {RouteInfo? parentRoute}) => location(
    parentRoute: parentRoute,
    id: args.id,
    pathParams: args.pathParams,
    queryParams: args.queryParams,
  );

  static final RegExp _pathParamPattern = RegExp(r':(\w+)');

  String _hydratePath(
    String template, {
    required String? id,
    required Map<String, String>? pathParams,
  }) {
    if (!template.contains(':')) return template;

    final params = <String, String>{...?pathParams};
    if (id != null && id.isNotEmpty) params.putIfAbsent('id', () => id);

    final missing = <String>[];
    final hydrated = template.replaceAllMapped(_pathParamPattern, (match) {
      final key = match.group(1)!;
      final value = params[key];
      if (value == null || value.isEmpty) {
        missing.add(key);
        return match.group(0)!;
      }
      return Uri.encodeComponent(value);
    });

    assert(
      missing.isEmpty,
      'Route "$name": missing path parameter(s) ${missing.join(', ')} for '
      '"$template". Pass them via pathParams (or id for ":id").',
    );
    return hydrated;
  }

  /// Joins a parent and child path the same way go_router's `concatenatePaths`
  /// does, so a built location matches the registered full path exactly.
  static String _joinPaths(String parentPath, String childPath) {
    final segments = <String>[
      ...parentPath.split('/'),
      ...childPath.split('/'),
    ].where((segment) => segment.isNotEmpty);
    return '/${segments.join('/')}';
  }

  /// A rich, JSON-safe diagnostic snapshot (closures become presence flags;
  /// the resolved policy is included).
  Map<String, dynamic> report({
    JsonOptions options = const JsonOptions(),
    Object? Function(dynamic)? toEncodable,
  }) => _rawReport().toJsonMap(options: options, toEncodable: toEncodable);

  Map<String, dynamic> _rawReport() => {
    'name': name,
    'path': path,
    'isBranch': isBranch,
    'forRedirectionOnly': forRedirectionOnly,
    'branchIndex': branchIndex,
    'branchKey': branchKey,
    'branchParentType': branchParentType,
    'deepLinkNames': deepLinkNames,
    'hasTitle': title != null,
    'hasBuilder': builder != null,
    'hasChild': child != null,
    'hasPageBuilder': pageBuilder != null,
    'hasRedirect': redirect != null,
    'hasDeepLinkHandler': deepLinkHandler != null,
    'policy': policy?.toMap(),
    'resolvedPolicy': resolvedPolicy.toMap(),
  };

  @override
  List<Object?> get props => [
    name,
    path,
    isBranch,
    forRedirectionOnly,
    branchIndex,
    branchKey,
    branchParentType,
    deepLinkNames,
    policy,
  ];
}

import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';

/// A comprehensive, cascading policy for route behavior.
///
/// Every field is nullable; `null` means "not set at this level, defer down the
/// chain" (`args.policy` -> `route.policy` -> [RouterBuilderConfig.defaults]).
/// Use [merge] as the single resolution primitive.
class RoutePolicy extends Equatable {
  /// Creates a route policy. All fields are optional and default to `null`.
  const RoutePolicy({
    this.mustBeAuthorized,
    this.duplicateBehavior,
    this.pushGlobally,
    this.isPopupRoute,
    this.visibleNavBar,
    this.isTopLevelOnly,
    this.shouldReplaceAll,
    this.deepLinkAllowed,
    this.deepLinkPushGlobally,
  });

  /// Whether authentication is required.
  final bool? mustBeAuthorized;

  /// How to handle navigating to a route already in the stack.
  final DuplicateRouteBehavior? duplicateBehavior;

  /// Whether to push on the root navigator.
  final bool? pushGlobally;

  /// Whether the route is presented as a dialog/sheet/popup.
  final bool? isPopupRoute;

  /// Whether the primary navigation UI stays visible.
  final bool? visibleNavBar;

  /// Whether the route stays at the top level of its navigator.
  final bool? isTopLevelOnly;

  /// Whether navigation replaces the entire stack.
  final bool? shouldReplaceAll;

  /// Whether the route is reachable via deep links.
  final bool? deepLinkAllowed;

  /// Whether a deep link to this route pushes on the root navigator.
  final bool? deepLinkPushGlobally;

  /// Preset: push on the root navigator.
  static const RoutePolicy global = RoutePolicy(pushGlobally: true);

  /// Preset: no authentication required.
  static const RoutePolicy public = RoutePolicy(mustBeAuthorized: false);

  /// Preset: presented as a popup.
  static const RoutePolicy popup = RoutePolicy(isPopupRoute: true);

  /// Returns a policy where `this` wins per field and [lower] fills the gaps.
  RoutePolicy merge(RoutePolicy? lower) {
    if (lower == null) return this;
    return RoutePolicy(
      mustBeAuthorized: mustBeAuthorized ?? lower.mustBeAuthorized,
      duplicateBehavior: duplicateBehavior ?? lower.duplicateBehavior,
      pushGlobally: pushGlobally ?? lower.pushGlobally,
      isPopupRoute: isPopupRoute ?? lower.isPopupRoute,
      visibleNavBar: visibleNavBar ?? lower.visibleNavBar,
      isTopLevelOnly: isTopLevelOnly ?? lower.isTopLevelOnly,
      shouldReplaceAll: shouldReplaceAll ?? lower.shouldReplaceAll,
      deepLinkAllowed: deepLinkAllowed ?? lower.deepLinkAllowed,
      deepLinkPushGlobally: deepLinkPushGlobally ?? lower.deepLinkPushGlobally,
    );
  }

  /// Returns a copy with the provided fields overridden.
  ///
  /// Note: a `null` argument leaves the existing value unchanged (copyWith
  /// cannot reset a field back to `null`).
  RoutePolicy copyWith({
    bool? mustBeAuthorized,
    DuplicateRouteBehavior? duplicateBehavior,
    bool? pushGlobally,
    bool? isPopupRoute,
    bool? visibleNavBar,
    bool? isTopLevelOnly,
    bool? shouldReplaceAll,
    bool? deepLinkAllowed,
    bool? deepLinkPushGlobally,
  }) {
    return RoutePolicy(
      mustBeAuthorized: mustBeAuthorized ?? this.mustBeAuthorized,
      duplicateBehavior: duplicateBehavior ?? this.duplicateBehavior,
      pushGlobally: pushGlobally ?? this.pushGlobally,
      isPopupRoute: isPopupRoute ?? this.isPopupRoute,
      visibleNavBar: visibleNavBar ?? this.visibleNavBar,
      isTopLevelOnly: isTopLevelOnly ?? this.isTopLevelOnly,
      shouldReplaceAll: shouldReplaceAll ?? this.shouldReplaceAll,
      deepLinkAllowed: deepLinkAllowed ?? this.deepLinkAllowed,
      deepLinkPushGlobally: deepLinkPushGlobally ?? this.deepLinkPushGlobally,
    );
  }

  /// Raw field map (values not yet normalized; enums stay as enums).
  Map<String, dynamic> toMap() => {
    'mustBeAuthorized': mustBeAuthorized,
    'duplicateBehavior': duplicateBehavior,
    'pushGlobally': pushGlobally,
    'isPopupRoute': isPopupRoute,
    'visibleNavBar': visibleNavBar,
    'isTopLevelOnly': isTopLevelOnly,
    'shouldReplaceAll': shouldReplaceAll,
    'deepLinkAllowed': deepLinkAllowed,
    'deepLinkPushGlobally': deepLinkPushGlobally,
  };

  /// A JSON-safe diagnostic snapshot (enums become their `.name`).
  Map<String, dynamic> report({
    JsonOptions options = const JsonOptions(),
    Object? Function(dynamic)? toEncodable,
  }) => toMap().toJsonMap(options: options, toEncodable: toEncodable);

  @override
  List<Object?> get props => [
    mustBeAuthorized,
    duplicateBehavior,
    pushGlobally,
    isPopupRoute,
    visibleNavBar,
    isTopLevelOnly,
    shouldReplaceAll,
    deepLinkAllowed,
    deepLinkPushGlobally,
  ];
}

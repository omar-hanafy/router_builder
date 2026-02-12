import 'package:equatable/equatable.dart';

/// Defines behavior when navigating to a route already in the stack.
enum DuplicateRouteBehavior {
  /// Push a new instance of the route onto the stack.
  duplicate,

  /// Replace the current route with updated parameters instead of pushing a new instance.
  refresh,

  /// Cancel the navigation entirely.
  doNothing;

  /// Returns `true` when this behavior pushes a new instance.
  bool get isDuplicate => this == duplicate;

  /// Returns `true` when this behavior replaces the existing route.
  bool get isRefresh => this == refresh;

  /// Returns `true` when this behavior cancels navigation.
  bool get isDoNothing => this == doNothing;
}

/// Convenient boolean checks for nullable [DuplicateRouteBehavior] instances.
extension DuplicateRouteBehaviorEx on DuplicateRouteBehavior? {
  /// Returns `true` when the optional behavior duplicates the route.
  bool get isDuplicate => this?.isDuplicate ?? false;

  /// Returns `true` when the optional behavior refreshes the route.
  bool get isRefresh => this?.isRefresh ?? false;

  /// Returns `true` when the optional behavior cancels navigation.
  bool get isDoNothing => this?.isDoNothing ?? false;
}

/// Defines a comprehensive policy for route behavior.
///
/// Use [RoutePolicy] to group behavioral configuration like authorization,
/// duplication handling, and presentation style.
class RoutePolicy extends Equatable {
  /// Creates a route policy.
  const RoutePolicy({
    this.mustBeAuthorized,
    this.duplicateBehavior,
    this.pushGlobally,
    this.isPopupRoute,
  });

  /// Whether authentication is required.
  final bool? mustBeAuthorized;

  /// How to handle duplicate navigation.
  final DuplicateRouteBehavior? duplicateBehavior;

  /// Whether to push to the root navigator.
  final bool? pushGlobally;

  /// Whether this is a popup route.
  final bool? isPopupRoute;

  @override
  List<Object?> get props => [
    mustBeAuthorized,
    duplicateBehavior,
    pushGlobally,
    isPopupRoute,
  ];
}

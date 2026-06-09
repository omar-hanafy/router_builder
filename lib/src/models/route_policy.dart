import 'package:equatable/equatable.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';

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

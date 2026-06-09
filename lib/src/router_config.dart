import 'package:router_builder/src/models/route_policy.dart';

/// Configuration for the router builder package.
///
/// Use this to set global defaults for route policies.
class RouterBuilderConfig {
  /// Private constructor to prevent instantiation.
  RouterBuilderConfig._();

  /// Global default policy.
  static RoutePolicy defaults = const RoutePolicy(
    mustBeAuthorized: true,
    duplicateBehavior: DuplicateRouteBehavior.duplicate,
    pushGlobally: false,
    isPopupRoute: false,
  );

  /// Sets the global default policy.
  static void setDefaults({
    bool? mustBeAuthorized,
    DuplicateRouteBehavior? duplicateBehavior,
    bool? pushGlobally,
    bool? isPopupRoute,
  }) {
    defaults = RoutePolicy(
      mustBeAuthorized: mustBeAuthorized ?? defaults.mustBeAuthorized,
      duplicateBehavior: duplicateBehavior ?? defaults.duplicateBehavior,
      pushGlobally: pushGlobally ?? defaults.pushGlobally,
      isPopupRoute: isPopupRoute ?? defaults.isPopupRoute,
    );
  }
}

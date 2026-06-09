import 'package:router_builder/src/models/duplicate_route_behavior.dart';
import 'package:router_builder/src/models/route_policy.dart';

/// Global configuration for router_builder.
///
/// Holds one complete [RoutePolicy] so resolution always terminates with
/// non-null values. Override it wholesale in `main()` (directly or via the
/// generated `installDefaults()`).
class RouterBuilderConfig {
  RouterBuilderConfig._();

  static const RoutePolicy _builtInDefaults = RoutePolicy(
    mustBeAuthorized: true,
    duplicateBehavior: DuplicateRouteBehavior.duplicate,
    pushGlobally: false,
    isPopupRoute: false,
    visibleNavBar: true,
    isTopLevelOnly: false,
    shouldReplaceAll: false,
    deepLinkAllowed: true,
    deepLinkPushGlobally: true,
  );

  static RoutePolicy _defaults = _builtInDefaults;

  static bool _isConfigured = false;

  /// The complete global default policy (always fully non-null).
  static RoutePolicy get defaults => _defaults;

  /// Overrides the global defaults; merges over the built-ins so the result
  /// stays complete.
  static void setDefaults(RoutePolicy policy) =>
      _defaults = policy.merge(_defaults);

  /// Restores the built-in defaults and clears [isConfigured] (use in tests).
  static void reset() {
    _defaults = _builtInDefaults;
    _isConfigured = false;
  }

  /// Whether [markConfigured] has run (e.g. via the generated installDefaults()).
  static bool get isConfigured => _isConfigured;

  /// Marks defaults as installed; enables optional debug fail-fast asserts.
  static void markConfigured() => _isConfigured = true;
}

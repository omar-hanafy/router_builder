/// Marks a static [RouteInfo] field for code generation.
///
/// Apply this annotation to static const/final RouteInfo fields to include them
/// in the generated route_info_helper.dart file.
///
/// Example:
/// ```dart
/// @RT()
/// static const home = RouteInfo('home', builder: (_, __) => HomeScreen());
/// ```
class RT {
  /// Creates an [RT] annotation.
  const RT();
}

/// Marks a `const RoutePolicy` as the app's global route defaults.
///
/// Exactly one declaration is allowed per package (the generator fails the
/// build on duplicates, or on a non-const / non-`RoutePolicy` target). The
/// generator emits `<RoutesHelper>.installDefaults()`; call it once in `main()`.
///
/// Example:
/// ```dart
/// @RTConfig()
/// const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);
/// ```
class RTConfig {
  /// Creates an [RTConfig] annotation.
  const RTConfig();
}

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

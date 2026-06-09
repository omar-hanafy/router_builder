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

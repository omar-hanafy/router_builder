// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Run: dart run build_runner build

// ignore_for_file: type=lint

import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:router_builder/router_builder.dart';
import 'package:router_builder_example/routes/app_routes.dart' as _i0;

/// Static constants for every defined route.
abstract class Routes {
  static const RouteInfo home = _i0.AppRoutes.home;
  static const RouteInfo dashboard = _i0.AppRoutes.dashboard;
  static const RouteInfo details = _i0.AppRoutes.details;
  static const RouteInfo admin = _i0.AppRoutes.adminPanel;
  static const RouteInfo login = _i0.AppRoutes.login;
  static const RouteInfo confirm = _i0.AppRoutes.confirmSheet;
  static const RouteInfo splash = _i0.AppRoutes.splashGate;
  static const RouteInfo homeTab = _i0.AppRoutes.homeTab;
  static const RouteInfo searchTab = _i0.AppRoutes.searchTab;
  static const RouteInfo profileTab = _i0.AppRoutes.profileTab;
  static const RouteInfo settings = _i0.settings;
}

/// Categorized routes and deep-link utilities.
abstract class RoutesHelper {
  /// Branch routes grouped by shell enum value.
  static final Map<_i0.AppShell, Map<int?, RouteInfo>> branches = {
    _i0.AppShell.home: {
      _i0.AppRoutes.homeTab.branchIndex: _i0.AppRoutes.homeTab,
    },
    _i0.AppShell.search: {
      _i0.AppRoutes.searchTab.branchIndex: _i0.AppRoutes.searchTab,
    },
    _i0.AppShell.profile: {
      _i0.AppRoutes.profileTab.branchIndex: _i0.AppRoutes.profileTab,
    },
  };

  /// Branches for `_i0.AppShell.home`.
  static final List<RouteInfo> homeBranches = [_i0.AppRoutes.homeTab];

  /// Branches for `_i0.AppShell.search`.
  static final List<RouteInfo> searchBranches = [_i0.AppRoutes.searchTab];

  /// Branches for `_i0.AppShell.profile`.
  static final List<RouteInfo> profileBranches = [_i0.AppRoutes.profileTab];

  /// Every annotated route (branches, standard, popup, global, redirect-only).
  static final List<RouteInfo> allRoutes = [
    ...branches.values.expand((m) => m.values),
    _i0.AppRoutes.home,
    _i0.AppRoutes.dashboard,
    _i0.AppRoutes.details,
    _i0.AppRoutes.adminPanel,
    _i0.AppRoutes.login,
    _i0.AppRoutes.confirmSheet,
    _i0.AppRoutes.splashGate,
    _i0.settings,
  ];

  /// Standard routes (non-branch, non-global, non-redirect).
  static List<RouteInfo> get normalRoutes =>
      allRoutes
          .where((r) => !r.isBranch && !r.forRedirectionOnly && !r.pushGlobally)
          .toList();

  /// Routes pushed on the root navigator.
  static List<RouteInfo> get globalRoutes =>
      allRoutes
          .where((r) => r.pushGlobally && !r.isBranch && !r.forRedirectionOnly)
          .toList();

  /// Popup routes.
  static List<RouteInfo> get popupRoutes =>
      allRoutes.where((r) => r.isPopupRoute).toList();

  /// Top-level-only routes.
  static List<RouteInfo> get topLevelRoutes =>
      allRoutes.where((r) => r.isTopLevelOnly).toList();

  /// Routes that require authorization.
  static List<RouteInfo> get authorizedRoutes =>
      allRoutes.where((r) => r.mustBeAuthorized).toList();

  /// Redirect-only routes.
  static List<RouteInfo> get redirectRoutes =>
      allRoutes.where((r) => r.forRedirectionOnly).toList();

  /// Lookup by deep-link key (route name, first path segment, alias).
  static final Map<String, RouteInfo> deepLinkMap = {
    'admin': _i0.AppRoutes.adminPanel,
    'confirm': _i0.AppRoutes.confirmSheet,
    'dashboard': _i0.AppRoutes.dashboard,
    'details': _i0.AppRoutes.details,
    'home': _i0.AppRoutes.home,
    'homeTab': _i0.AppRoutes.homeTab,
    'item': _i0.AppRoutes.details,
    'items': _i0.AppRoutes.details,
    'login': _i0.AppRoutes.login,
    'product': _i0.AppRoutes.details,
    'profileTab': _i0.AppRoutes.profileTab,
    'searchTab': _i0.AppRoutes.searchTab,
    'settings': _i0.settings,
    'splash': _i0.AppRoutes.splashGate,
  };

  /// Returns the [RouteInfo] for [name], or null.
  static RouteInfo? fromName(String? name) =>
      allRoutes.firstWhereOrNull((route) => route.name == name);

  /// Resolves a deep-link URI into a [RouteInfo] and [RouteArgs].
  static DeepLinkMatch? resolveDeepLink(
    Uri incoming, {
    Iterable<String> allowedHosts = const [],
  }) {
    final normalized = DeepLinkMatcher.normalizeToAppPath(
      incoming,
      hosts: allowedHosts,
    );
    return const DeepLinkMatcher().match(
      normalized,
      allRoutes,
      original: incoming,
    );
  }

  /// Normalizes an incoming deep-link URI to an app-internal path.
  static Uri normalizeToAppPath(
    Uri incoming, {
    Iterable<String> allowedHosts = const [],
  }) => DeepLinkMatcher.normalizeToAppPath(incoming, hosts: allowedHosts);

  /// Branch routes for [shell], or null.
  static Map<int?, RouteInfo>? branchesFor(_i0.AppShell shell) =>
      branches[shell];

  /// All branch routes across shells.
  static List<RouteInfo> allBranches() =>
      branches.values.expand((m) => m.values).toList();

  /// Branch route for [shell] at [index], or null.
  static RouteInfo? branchByIndex(_i0.AppShell shell, int? index) =>
      branches[shell]?[index];

  /// Whether [route] belongs to [shell].
  static bool isRouteInShell(RouteInfo route, _i0.AppShell shell) =>
      branches[shell]?.containsValue(route) ?? false;

  /// Finds a branch route by its [key].
  static RouteInfo? branchByKey(String key) => branches.values
      .expand((m) => m.values)
      .firstWhereOrNull((route) => route.branchKey == key);

  /// Installs the app's @RTConfig policy as global defaults. Call once in main().
  static void installDefaults() {
    RouterBuilderConfig.setDefaults(_i0.appRoutePolicy);
    RouterBuilderConfig.markConfigured();
  }
}

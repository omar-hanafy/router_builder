// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Run: dart run build_runner build

// ignore_for_file: type=lint

import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:router_builder/router_builder.dart';
import 'package:router_builder_example/routes/app_routes.dart';

/// Static constants for every defined route.
abstract class Routes {
  static const RouteInfo home = AppRoutes.home;
  static const RouteInfo dashboard = AppRoutes.dashboard;
  static const RouteInfo details = AppRoutes.details;
  static const RouteInfo admin = AppRoutes.adminPanel;
  static const RouteInfo login = AppRoutes.login;
  static const RouteInfo confirm = AppRoutes.confirmSheet;
  static const RouteInfo splash = AppRoutes.splashGate;
  static const RouteInfo homeTab = AppRoutes.homeTab;
  static const RouteInfo searchTab = AppRoutes.searchTab;
  static const RouteInfo profileTab = AppRoutes.profileTab;
  static const RouteInfo settings = settings;
}

/// Categorized routes and deep-link utilities.
abstract class RoutesHelper {
  /// Branch routes grouped by shell enum value.
  static final Map<AppShell, Map<int?, RouteInfo>> branches = {
    AppShell.home: {AppRoutes.homeTab.branchIndex: AppRoutes.homeTab},
    AppShell.search: {AppRoutes.searchTab.branchIndex: AppRoutes.searchTab},
    AppShell.profile: {AppRoutes.profileTab.branchIndex: AppRoutes.profileTab},
  };

  /// Branches for `AppShell.home`.
  static final List<RouteInfo> homeBranches = [AppRoutes.homeTab];

  /// Branches for `AppShell.search`.
  static final List<RouteInfo> searchBranches = [AppRoutes.searchTab];

  /// Branches for `AppShell.profile`.
  static final List<RouteInfo> profileBranches = [AppRoutes.profileTab];

  /// Every annotated route (branches, standard, popup, global, redirect-only).
  static final List<RouteInfo> allRoutes = [
    ...branches.values.expand((m) => m.values),
    AppRoutes.home,
    AppRoutes.dashboard,
    AppRoutes.details,
    AppRoutes.adminPanel,
    AppRoutes.login,
    AppRoutes.confirmSheet,
    AppRoutes.splashGate,
    settings,
  ];

  /// Standard routes (non-branch, non-global, non-redirect).
  static List<RouteInfo> get normalRoutes => allRoutes
      .where((r) => !r.isBranch && !r.forRedirectionOnly && !r.pushGlobally)
      .toList();

  /// Routes pushed on the root navigator.
  static List<RouteInfo> get globalRoutes => allRoutes
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
    'admin': AppRoutes.adminPanel,
    'confirm': AppRoutes.confirmSheet,
    'dashboard': AppRoutes.dashboard,
    'details': AppRoutes.details,
    'home': AppRoutes.home,
    'homeTab': AppRoutes.homeTab,
    'item': AppRoutes.details,
    'items': AppRoutes.details,
    'login': AppRoutes.login,
    'product': AppRoutes.details,
    'profileTab': AppRoutes.profileTab,
    'searchTab': AppRoutes.searchTab,
    'settings': settings,
    'splash': AppRoutes.splashGate,
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
  static Map<int?, RouteInfo>? branchesFor(AppShell shell) => branches[shell];

  /// All branch routes across shells.
  static List<RouteInfo> allBranches() =>
      branches.values.expand((m) => m.values).toList();

  /// Branch route for [shell] at [index], or null.
  static RouteInfo? branchByIndex(AppShell shell, int? index) =>
      branches[shell]?[index];

  /// Whether [route] belongs to [shell].
  static bool isRouteInShell(RouteInfo route, AppShell shell) =>
      branches[shell]?.containsValue(route) ?? false;

  /// Finds a branch route by its [key].
  static RouteInfo? branchByKey(String key) => branches.values
      .expand((m) => m.values)
      .firstWhereOrNull((route) => route.branchKey == key);

  /// Installs the app's @RTConfig policy as global defaults. Call once in main().
  static void installDefaults() {
    RouterBuilderConfig.setDefaults(appRoutePolicy);
    RouterBuilderConfig.markConfigured();
  }
}

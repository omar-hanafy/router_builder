import 'package:flutter/material.dart';
import 'package:router_builder/router_builder.dart';

/// Shell tabs for bottom navigation (exercises branch routes + enum grouping).
enum AppShell { home, search, profile }

/// App-wide route defaults, installed via RoutesHelper.installDefaults().
@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);

/// A top-level route (exercises top-level @RT discovery, D15).
@RT()
const settings = RouteInfo(
  'settings',
  child: SizedBox(),
  policy: RoutePolicy(isTopLevelOnly: true),
);

/// Class-hosted routes covering the remaining cases.
abstract class AppRoutes {
  /// Standard route built from a static child.
  @RT()
  static const home = RouteInfo('home', child: SizedBox());

  /// Standard route built from a builder.
  @RT()
  static const dashboard = RouteInfo('dashboard', builder: _dashboard);

  /// Standard route with a custom page, a path template, and deep-link aliases.
  @RT()
  static const details = RouteInfo(
    'details',
    path: '/items/:id',
    pageBuilder: _detailsPage,
    deepLinkNames: ['item', 'product'],
  );

  /// Global route (pushed on the root navigator).
  @RT()
  static const adminPanel = RouteInfo(
    'admin',
    child: SizedBox(),
    policy: RoutePolicy.global,
  );

  /// Public route (no auth required).
  @RT()
  static const login = RouteInfo(
    'login',
    child: SizedBox(),
    policy: RoutePolicy.public,
  );

  /// Popup route.
  @RT()
  static const confirmSheet = RouteInfo(
    'confirm',
    child: SizedBox(),
    policy: RoutePolicy.popup,
  );

  /// Redirect-only route.
  @RT()
  static const splashGate = RouteInfo.redirect(
    'splash',
    redirect: _gate,
    path: '/splash',
  );

  /// Home shell branch.
  @RT()
  static const homeTab = RouteInfo.branch(
    'homeTab',
    branchIndex: 0,
    branchKey: '_homeNav',
    branchParentType: AppShell.home,
    child: SizedBox(),
  );

  /// Search shell branch.
  @RT()
  static const searchTab = RouteInfo.branch(
    'searchTab',
    branchIndex: 1,
    branchKey: '_searchNav',
    branchParentType: AppShell.search,
    child: SizedBox(),
  );

  /// Profile shell branch.
  @RT()
  static const profileTab = RouteInfo.branch(
    'profileTab',
    branchIndex: 2,
    branchKey: '_profileNav',
    branchParentType: AppShell.profile,
    child: SizedBox(),
  );
}

Widget _dashboard(BuildContext context, RouteArgs? args) => const SizedBox();

Page<dynamic> _detailsPage(BuildContext context, RouteArgs? args) =>
    const MaterialPage<dynamic>(child: SizedBox());

String? _gate(BuildContext context, RouteArgs? args) => AppRoutes.login.path;

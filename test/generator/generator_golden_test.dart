@Tags(['generator'])
library;

import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

const _comprehensive = '''
import 'package:flutter/material.dart';
import 'package:router_builder/router_builder.dart';

enum AppShell { home, search, profile }

@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);

@RT()
const settings = RouteInfo('settings', child: SizedBox(),
    policy: RoutePolicy(isTopLevelOnly: true));

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());
  @RT()
  static const dashboard = RouteInfo('dashboard', builder: _b);
  @RT()
  static const details = RouteInfo('details', path: '/items/:id',
      pageBuilder: _p, deepLinkNames: ['item', 'product']);
  @RT()
  static const adminPanel =
      RouteInfo('admin', child: SizedBox(), policy: RoutePolicy.global);
  @RT()
  static const login =
      RouteInfo('login', child: SizedBox(), policy: RoutePolicy.public);
  @RT()
  static const confirmSheet =
      RouteInfo('confirm', child: SizedBox(), policy: RoutePolicy.popup);
  @RT()
  static const splashGate =
      RouteInfo.redirect('splash', redirect: _g, path: '/splash');
  @RT()
  static const homeTab = RouteInfo.branch('homeTab', branchIndex: 0,
      branchKey: '_h', branchParentType: AppShell.home, child: SizedBox());
  @RT()
  static const searchTab = RouteInfo.branch('searchTab', branchIndex: 1,
      branchKey: '_s', branchParentType: AppShell.search, child: SizedBox());
  @RT()
  static const profileTab = RouteInfo.branch('profileTab', branchIndex: 2,
      branchKey: '_p', branchParentType: AppShell.profile, child: SizedBox());
}

Widget _b(BuildContext c, RouteArgs? a) => const SizedBox();
Page<dynamic> _p(BuildContext c, RouteArgs? a) =>
    const MaterialPage<dynamic>(child: SizedBox());
String? _g(BuildContext c, RouteArgs? a) => AppRoutes.login.path;
''';

void main() {
  test('one generation covers every supported case', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': _comprehensive}),
      rootPackage: 'router_builder',
      readerWriter: await reader(),
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(<Matcher>[
            // route constants (standard, top-level, branch, redirect)
            matches(RegExp(r'RouteInfo home = _i\d+\.AppRoutes\.home')),
            matches(RegExp(r'RouteInfo settings = _i\d+\.settings')),
            matches(RegExp(r'RouteInfo splash = _i\d+\.AppRoutes\.splashGate')),
            // branch map + per-enum lists keyed by the shell enum
            matches(
              RegExp(r'Map<_i\d+\.AppShell, Map<int\?, RouteInfo>> branches'),
            ),
            contains('homeBranches'),
            contains('searchBranches'),
            contains('profileBranches'),
            // allRoutes includes redirect-only
            contains('AppRoutes.splashGate'),
            // all runtime category getters
            contains('get normalRoutes'),
            contains('get globalRoutes'),
            contains('get popupRoutes'),
            contains('get topLevelRoutes'),
            contains('get authorizedRoutes'),
            contains('get redirectRoutes'),
            // deep-link keys: name, aliases, path segment
            contains("'details':"),
            contains("'item':"),
            contains("'product':"),
            contains("'items':"),
            // @RTConfig wiring
            matches(
              RegExp(
                r'RouterBuilderConfig\.setDefaults\(_i\d+\.appRoutePolicy\)',
              ),
            ),
          ]),
        ),
      },
    );
  });
}

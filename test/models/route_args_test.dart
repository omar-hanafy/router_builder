import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  group('RouteArgs.effectivePolicy precedence', () {
    test('args policy wins over route policy wins over defaults', () {
      const route = RouteInfo(
        'p',
        child: SizedBox(),
        policy: RoutePolicy(mustBeAuthorized: false, pushGlobally: true),
      );
      const args = RouteArgs(route, policy: RoutePolicy(pushGlobally: false));
      expect(args.effectivePushGlobally, isFalse); // args wins
      expect(args.effectiveMustBeAuthorized, isFalse); // from route
      expect(args.effectiveVisibleNavBar, isTrue); // from defaults
    });

    test('branch args setting a forced field assert in debug', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
      );
      const args = RouteArgs(branch, policy: RoutePolicy(pushGlobally: true));
      expect(() => args.effectivePolicy, throwsA(isA<AssertionError>()));
    });

    test('branch deepLinkPushGlobally is forced false without conflict', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
      );
      const args = RouteArgs(branch);
      expect(args.effectiveDeepLinkPushGlobally, isFalse);
    });
  });

  group('RouteArgs copyWith / cleared', () {
    test('copyWith overrides policy and keeps route', () {
      const route = RouteInfo('p', child: SizedBox());
      const args = RouteArgs(route, id: '1');
      final c = args.copyWith(policy: const RoutePolicy(pushGlobally: true));
      expect(c.id, '1');
      expect(c.effectivePushGlobally, isTrue);
    });

    test('cleared drops resumeTo/comingFrom but keeps nav context', () {
      const route = RouteInfo('p', child: SizedBox());
      const prev = RouteArgs(route);
      const args = RouteArgs(route, id: '1', resumeTo: prev, comingFrom: prev);
      final cleared = args.cleared();
      expect(cleared.id, '1');
      expect(cleared.resumeTo, isNull);
      expect(cleared.comingFrom, isNull);
    });
  });

  group('RouteArgs subclassing', () {
    test('forwards policy via super-params and resolves', () {
      const route = RouteInfo('dlg', child: SizedBox());
      const args = _DialogArgs(route, policy: RoutePolicy.popup);
      expect(args.effectiveIsPopupRoute, isTrue);
    });
  });

  group('RouteArgs.report', () {
    test(
      'is JSON encodable with effective policy and shallow route summary',
      () {
        const route = RouteInfo('p', child: SizedBox());
        final args = RouteArgs(route, id: '7', object: _NotEncodable());
        final map = args.report(
          toEncodable: (v) => v is _NotEncodable ? 'X' : v,
        );
        expect(() => jsonEncode(map), returnsNormally);
        expect((map['route'] as Map)['name'], 'p');
        expect(map['object'], 'X');
        expect((map['effectivePolicy'] as Map)['mustBeAuthorized'], isTrue);
      },
    );
  });

  test('RouteArgsX.requiresAuth', () {
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(route);
    expect(args.requiresAuth, isTrue);
    const RouteArgs? none = null;
    expect(none.requiresAuth, isFalse);
  });
}

enum _Shell { market }

class _DialogArgs extends RouteArgs {
  const _DialogArgs(super.route, {super.policy});
}

class _NotEncodable {}

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  group('RouteInfo resolved getters', () {
    test('fall back to global defaults when policy is null', () {
      const r = RouteInfo('home', child: SizedBox());
      expect(r.mustBeAuthorized, isTrue);
      expect(r.pushGlobally, isFalse);
      expect(r.duplicateBehavior, DuplicateRouteBehavior.duplicate);
      expect(r.deepLinkAllowed, isTrue);
      expect(r.deepLinkPushGlobally, isTrue);
      expect(r.visibleNavBar, isTrue);
    });

    test('route.policy overrides defaults', () {
      const r = RouteInfo(
        'admin',
        child: SizedBox(),
        policy: RoutePolicy(pushGlobally: true, mustBeAuthorized: false),
      );
      expect(r.pushGlobally, isTrue);
      expect(r.mustBeAuthorized, isFalse);
    });

    test('installed global defaults reflect in resolved getters', () {
      RouterBuilderConfig.setDefaults(const RoutePolicy(mustBeAuthorized: false));
      const r = RouteInfo('home', child: SizedBox());
      expect(r.mustBeAuthorized, isFalse);
    });
  });

  group('RouteInfo.constrain', () {
    test('branch forces structural fields false (no conflict needed)', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
      );
      final resolved = branch.resolvedPolicy;
      expect(resolved.pushGlobally, isFalse);
      expect(resolved.isPopupRoute, isFalse);
      // default deepLinkPushGlobally is true; the branch constraint forces false
      expect(resolved.deepLinkPushGlobally, isFalse);
    });

    test('branch policy conflicting with a forced field asserts in debug', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
        policy: RoutePolicy(pushGlobally: true),
      );
      expect(() => branch.resolvedPolicy, throwsA(isA<AssertionError>()));
    });

    test('redirect forces isPopupRoute/visibleNavBar/shouldReplaceAll false', () {
      const redirect = RouteInfo.redirect('gate', redirect: _noRedirect);
      final resolved = redirect.resolvedPolicy;
      expect(resolved.isPopupRoute, isFalse);
      expect(resolved.visibleNavBar, isFalse);
      expect(resolved.shouldReplaceAll, isFalse);
    });
  });

  group('RouteInfo equality', () {
    test('props include branchParentType and deepLinkNames', () {
      const a = RouteInfo('e', child: SizedBox(), deepLinkNames: ['x']);
      const b = RouteInfo('e', child: SizedBox(), deepLinkNames: ['y']);
      expect(a, isNot(equals(b)));
    });
  });

  group('RouteInfo.report', () {
    test('is JSON encodable with presence flags and resolved policy', () {
      const r = RouteInfo('home', builder: _build, deepLinkNames: ['h']);
      final map = r.report();
      expect(() => jsonEncode(map), returnsNormally);
      expect(map['hasBuilder'], isTrue);
      expect(map['hasChild'], isFalse);
      expect((map['resolvedPolicy'] as Map)['mustBeAuthorized'], isTrue);
    });
  });
}

enum _Shell { market }

String? _noRedirect(BuildContext context, RouteArgs? args) => null;

Widget _build(BuildContext context, RouteArgs? args) => const SizedBox();

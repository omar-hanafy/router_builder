import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  group('RoutePolicy.merge', () {
    test('this wins per field; lower fills gaps', () {
      const upper = RoutePolicy(mustBeAuthorized: false, pushGlobally: true);
      const lower = RoutePolicy(mustBeAuthorized: true, isPopupRoute: true);
      final merged = upper.merge(lower);
      expect(merged.mustBeAuthorized, isFalse); // upper wins
      expect(merged.pushGlobally, isTrue); // only upper set it
      expect(merged.isPopupRoute, isTrue); // filled from lower
      expect(merged.visibleNavBar, isNull); // neither set it
    });

    test('merge(null) returns this', () {
      const p = RoutePolicy(pushGlobally: true);
      expect(p.merge(null), equals(p));
    });
  });

  group('RoutePolicy.copyWith', () {
    test('overrides only provided fields', () {
      const p = RoutePolicy(mustBeAuthorized: true, visibleNavBar: true);
      final c = p.copyWith(visibleNavBar: false);
      expect(c.mustBeAuthorized, isTrue);
      expect(c.visibleNavBar, isFalse);
    });
  });

  group('RoutePolicy presets', () {
    test('expose common shapes', () {
      expect(RoutePolicy.global.pushGlobally, isTrue);
      expect(RoutePolicy.public.mustBeAuthorized, isFalse);
      expect(RoutePolicy.popup.isPopupRoute, isTrue);
    });
  });

  group('RoutePolicy equality', () {
    test('value equality across all nine fields', () {
      expect(
        const RoutePolicy(deepLinkPushGlobally: false),
        equals(const RoutePolicy(deepLinkPushGlobally: false)),
      );
      expect(
        const RoutePolicy(deepLinkPushGlobally: false),
        isNot(equals(const RoutePolicy(deepLinkPushGlobally: true))),
      );
    });
  });

  group('RoutePolicy.report', () {
    test('is JSON encodable and serializes enums by name', () {
      const p = RoutePolicy(
        mustBeAuthorized: false,
        duplicateBehavior: DuplicateRouteBehavior.refresh,
      );
      final map = p.report();
      expect(() => jsonEncode(map), returnsNormally);
      expect(map['duplicateBehavior'], 'refresh');
      expect(map['mustBeAuthorized'], isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  test('built-in defaults are complete (all nine fields non-null)', () {
    final d = RouterBuilderConfig.defaults;
    expect(d.mustBeAuthorized, isTrue);
    expect(d.duplicateBehavior, DuplicateRouteBehavior.duplicate);
    expect(d.pushGlobally, isFalse);
    expect(d.isPopupRoute, isFalse);
    expect(d.visibleNavBar, isTrue);
    expect(d.isTopLevelOnly, isFalse);
    expect(d.shouldReplaceAll, isFalse);
    expect(d.deepLinkAllowed, isTrue);
    expect(d.deepLinkPushGlobally, isTrue);
  });

  test('setDefaults overrides yet stays complete', () {
    RouterBuilderConfig.setDefaults(
      const RoutePolicy(mustBeAuthorized: false, deepLinkAllowed: false),
    );
    final d = RouterBuilderConfig.defaults;
    expect(d.mustBeAuthorized, isFalse); // overridden
    expect(d.deepLinkAllowed, isFalse); // overridden
    expect(d.visibleNavBar, isTrue); // still complete from built-ins
    expect(d.duplicateBehavior, DuplicateRouteBehavior.duplicate);
  });

  test('reset restores built-ins and clears configured flag', () {
    RouterBuilderConfig.setDefaults(const RoutePolicy(mustBeAuthorized: false));
    RouterBuilderConfig.markConfigured();
    RouterBuilderConfig.reset();
    expect(RouterBuilderConfig.defaults.mustBeAuthorized, isTrue);
    expect(RouterBuilderConfig.isConfigured, isFalse);
  });

  test('markConfigured flips isConfigured', () {
    expect(RouterBuilderConfig.isConfigured, isFalse);
    RouterBuilderConfig.markConfigured();
    expect(RouterBuilderConfig.isConfigured, isTrue);
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

/// Golden precedence matrix: for each field, args.policy beats route.policy
/// beats installed defaults. Each row sets exactly one layer and asserts the
/// effective value.
void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  test('args layer wins for every boolean field', () {
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(
      route,
      policy: RoutePolicy(
        mustBeAuthorized: false,
        pushGlobally: true,
        isPopupRoute: true,
        visibleNavBar: false,
        isTopLevelOnly: true,
        shouldReplaceAll: true,
        deepLinkAllowed: false,
        deepLinkPushGlobally: false,
      ),
    );
    expect(args.effectiveMustBeAuthorized, isFalse);
    expect(args.effectivePushGlobally, isTrue);
    expect(args.effectiveIsPopupRoute, isTrue);
    expect(args.effectiveVisibleNavBar, isFalse);
    expect(args.effectiveIsTopLevelOnly, isTrue);
    expect(args.effectiveShouldReplaceAll, isTrue);
    expect(args.effectiveDeepLinkAllowed, isFalse);
    expect(args.effectiveDeepLinkPushGlobally, isFalse);
  });

  test('route layer wins when args is silent', () {
    const route = RouteInfo(
      'p',
      child: SizedBox(),
      policy: RoutePolicy(isTopLevelOnly: true, mustBeAuthorized: false),
    );
    const args = RouteArgs(route);
    expect(args.effectiveIsTopLevelOnly, isTrue);
    expect(args.effectiveMustBeAuthorized, isFalse);
  });

  test('installed defaults win when args and route are silent', () {
    RouterBuilderConfig.setDefaults(
      const RoutePolicy(duplicateBehavior: DuplicateRouteBehavior.refresh),
    );
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(route);
    expect(args.effectiveDuplicateBehavior, DuplicateRouteBehavior.refresh);
  });

  test('built-in defaults win when nothing is configured', () {
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(route);
    expect(args.effectiveDuplicateBehavior, DuplicateRouteBehavior.duplicate);
    expect(args.effectiveMustBeAuthorized, isTrue);
    expect(args.effectiveVisibleNavBar, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';
import 'package:router_builder_example/main.dart' as app;
import 'package:router_builder_example/routes/app_routes.dart';
import 'package:router_builder_example/routes.g.dart';

void main() {
  tearDown(RouterBuilderConfig.reset);

  test('typed constants and shell branches reference the declared routes', () {
    const RouteInfo details = Routes.details;
    expect(details, same(AppRoutes.details));
    expect(RoutesHelper.fromName('settings'), same(settings));
    expect(
      RoutesHelper.branchByIndex(AppShell.search, 1),
      same(Routes.searchTab),
    );
    expect(RoutesHelper.deepLinkMap['product'], same(details));
  });

  test('generated helper resolves the item URI with the app policy', () {
    RoutesHelper.installDefaults();

    final uri = Uri.parse('https://example.com/items/42?source=mail');
    final DeepLinkMatch? match = RoutesHelper.resolveDeepLink(
      uri,
      allowedHosts: const ['example.com'],
    );

    expect(match, isNotNull);
    expect(match!.route, same(Routes.details));
    expect(match.args.id, '42');
    expect(match.args.pathParams, {'id': '42'});
    expect(match.args.queryParams, {'source': 'mail'});
    expect(match.args.object, uri);
    expect(match.args.effectiveMustBeAuthorized, isFalse);
  });

  testWidgets('example displays the matched item and shell branches', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Deep link -> details (id=42)'), findsOneWidget);
    expect(find.text('Branches: 3'), findsOneWidget);
  });
}

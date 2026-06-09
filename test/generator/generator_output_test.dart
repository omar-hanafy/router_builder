import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

void main() {
  test('emits runtime category getters and includes redirect routes', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': basicFixture}),
      rootPackage: 'router_builder',
      readerWriter: await reader(),
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(
            contains('static List<RouteInfo> get normalRoutes'),
            contains('static List<RouteInfo> get redirectRoutes'),
            contains('static List<RouteInfo> get authorizedRoutes'),
            contains('static final List<RouteInfo> allRoutes'),
            contains('AppRoutes.gate'), // redirect-only present in allRoutes
            contains('static final Map<String, RouteInfo> deepLinkMap'),
            contains('static void installDefaults()'),
          ),
        ),
      },
    );
  });
}

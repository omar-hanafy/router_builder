import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

void main() {
  test('defaults to Routes/RoutesHelper at lib/routes.g.dart', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': basicFixture}),
      rootPackage: 'router_builder',
      readerWriter: await reader(),
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(contains('abstract class Routes'),
              contains('abstract class RoutesHelper')),
        ),
      },
    );
  });

  test('honors custom class names and output path', () async {
    await testBuilder(
      generator({
        'output': 'lib/nav.g.dart',
        'route_class_name': 'AppRoute',
        'helper_class_name': 'NavHelper',
      }),
      assets({'lib/app_routes.dart': basicFixture}),
      rootPackage: 'router_builder',
      readerWriter: await reader(),
      outputs: {
        'router_builder|lib/nav.g.dart': decodedMatches(
          allOf(contains('abstract class AppRoute'),
              contains('abstract class NavHelper')),
        ),
      },
    );
  });
}

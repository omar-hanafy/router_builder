import 'package:build_config/build_config.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

void main() {
  test('build.yaml declares the default builder inputs and outputs', () async {
    final config = await BuildConfig.fromPackageDir('.');
    const key = 'router_builder_generator:generate_route_info_helper';
    expect(
      config.builderDefinitions[key]?.buildExtensions,
      generator().buildExtensions,
    );
  });

  test('defaults to Routes/RoutesHelper at lib/routes.g.dart', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': basicFixture}),
      rootPackage: rootPackage,
      readerWriter: stubReader(),
      outputs: {
        defaultOutput: decodedMatches(
          allOf(
            contains('abstract class Routes'),
            contains('abstract class RoutesHelper'),
          ),
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
      rootPackage: rootPackage,
      readerWriter: stubReader(),
      outputs: {
        '$rootPackage|lib/nav.g.dart': decodedMatches(
          allOf(
            contains('abstract class AppRoute'),
            contains('abstract class NavHelper'),
          ),
        ),
      },
    );
  });
}

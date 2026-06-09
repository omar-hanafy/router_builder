import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

const _topLevelFixture = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

@RT()
const settings = RouteInfo('settings', child: SizedBox());

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());
}
''';

void main() {
  test('discovers class statics AND top-level consts', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': _topLevelFixture}),
      rootPackage: 'router_builder',
      readerWriter: await reader(),
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(contains('AppRoutes.home'), contains('settings')),
        ),
      },
    );
  });
}

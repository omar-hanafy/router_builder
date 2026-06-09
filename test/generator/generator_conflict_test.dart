@Tags(['generator'])
library;

import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

const _conflict = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

abstract class AppRoutes {
  @RT()
  static const a = RouteInfo('dup', child: SizedBox());

  @RT()
  static const b = RouteInfo('other', deepLinkNames: ['dup'], child: SizedBox());
}
''';

void main() {
  // build_test 3.5.15 does NOT reject the testBuilder future when a builder
  // throws; build_runner catches the error, logs it, and returns a failed
  // `TestBuilderResult` (see TestBuilderResult.succeeded/errors). So the build
  // failure is asserted via `succeeded`/`errors` rather than throwsA. The
  // generator still throws RouterBuilderError; its message surfaces in `errors`.
  test('deep-link key conflict fails the build by default', () async {
    final result = await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': _conflict}),
      rootPackage: 'router_builder',
      readerWriter: await reader(),
      onLog: (_) {},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.join('\n'), contains('RouterBuilderError'));
  });

  test('fail_on_conflict:false keeps the build green', () async {
    await testBuilder(
      generator({'fail_on_conflict': false}),
      assets({'lib/app_routes.dart': _conflict}),
      rootPackage: 'router_builder',
      readerWriter: await reader(),
      onLog: (_) {},
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          contains('deepLinkMap'),
        ),
      },
    );
  });
}

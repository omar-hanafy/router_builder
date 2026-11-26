import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

const _single = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());
}
''';

const _duplicate = '''
import 'package:router_builder/router_builder.dart';

@RTConfig()
const a = RoutePolicy(mustBeAuthorized: false);
@RTConfig()
const b = RoutePolicy(pushGlobally: true);
''';

const _nonConst = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

@RTConfig()
final appRoutePolicy = RoutePolicy(mustBeAuthorized: someFlag());
bool someFlag() => false;
''';

void main() {
  // See generator_conflict_test.dart: build_test 3.5.15 does not reject the
  // future on a thrown builder error; assert via succeeded/errors instead.
  test('single @RTConfig wires installDefaults to its value', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': _single}),
      rootPackage: rootPackage,
      readerWriter: stubReader(),
      outputs: {
        defaultOutput: decodedMatches(
          matches(
            RegExp(
              r'RouterBuilderConfig\.setDefaults\(_i\d+\.appRoutePolicy\)',
            ),
          ),
        ),
      },
    );
  });

  test('duplicate @RTConfig fails the build', () async {
    final result = await testBuilder(
      generator(),
      assets({'lib/c.dart': _duplicate}),
      rootPackage: rootPackage,
      readerWriter: stubReader(),
      onLog: (_) {},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.join('\n'), contains('RouterBuilderError'));
  });

  test('non-const @RTConfig fails the build', () async {
    final result = await testBuilder(
      generator(),
      assets({'lib/c.dart': _nonConst}),
      rootPackage: rootPackage,
      readerWriter: stubReader(),
      onLog: (_) {},
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.join('\n'), contains('RouterBuilderError'));
  });
}

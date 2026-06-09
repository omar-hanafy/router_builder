import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:router_builder/builder.dart';

/// Prefixes fixture paths with the router_builder package id for testBuilder.
Map<String, Object> assets(Map<String, String> sources) => {
  for (final e in sources.entries) 'router_builder|${e.key}': e.value,
};

/// The generator under test, configured with [options].
Builder generator([Map<String, dynamic> options = const {}]) =>
    generateRouteInfoHelperBuilder(BuilderOptions(options));

/// A disk-backed reader/writer for `testBuilder`.
///
/// build_test's default in-memory resolver only sees the assets passed to
/// `testBuilder`; it cannot resolve `package:flutter` or `package:router_builder`
/// from disk (test_builder.dart documents that `packageConfig` is "not used for
/// reading of files"). Without this, `@RT`/`RouteInfo` resolve to `InvalidType`
/// and `ElementAnnotation.element` is `null`. `loadIsolateSources()` copies the
/// current isolate's package sources (flutter + router_builder) into the reader
/// so annotations and field types resolve. A fresh instance per call keeps tests
/// isolated.
Future<TestReaderWriter> reader() async {
  final rw = TestReaderWriter(rootPackage: 'router_builder');
  await rw.testing.loadIsolateSources();
  return rw;
}

/// A minimal fixture: one standard route + one redirect-only route.
const String basicFixture = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());

  @RT()
  static const gate = RouteInfo.redirect('gate', redirect: _to);
}

String? _to(BuildContext c, RouteArgs? a) => null;
''';

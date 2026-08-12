import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:router_builder_generator/builder.dart';

/// Package the fixtures are compiled under (the "app" being generated for).
const String rootPackage = 'example_app';

/// The generator under test, configured with [options].
Builder generator([Map<String, dynamic> options = const {}]) =>
    generateRouteInfoHelperBuilder(BuilderOptions(options));

/// Wraps fixture sources with the root package id.
///
/// Fixture paths are given relative to the package root, e.g.
/// `{'lib/app_routes.dart': source}`. Only these become build inputs — the
/// stub packages are seeded into [stubReader] instead, so the aggregating
/// builder runs for the fixture package alone.
Map<String, String> assets(Map<String, String> sources) => {
  for (final e in sources.entries) '$rootPackage|${e.key}': e.value,
};

/// A reader seeded with the stub `flutter` and `router_builder` sources.
///
/// A fresh instance per call keeps tests isolated.
TestReaderWriter stubReader() {
  final rw = TestReaderWriter(rootPackage: rootPackage);
  _stubPackages.forEach(
    (id, source) => rw.testing.writeString(AssetId.parse(id), source),
  );
  return rw;
}

/// Asset id of the default generated output for the fixture package.
const String defaultOutput = '$rootPackage|lib/routes.g.dart';

/// Stand-in sources for `package:flutter` and `package:router_builder`.
///
/// The generator inspects only the resolved element model — constructor names,
/// field names, and whether `branchParentType` is an enum — never Flutter's
/// real behaviour. Stubs are therefore sufficient, and they are what keeps this
/// package pure Dart: depending on real Flutter would drag the SDK's exact
/// `meta` pin into this resolution and cap `analyzer` below 13.1.0, which is
/// precisely the blocking this package exists to avoid.
///
/// Real-Flutter coverage lives in `example/`, which builds against the actual
/// runtime package.
const Map<String, String> _stubPackages = {
  'flutter|lib/widgets.dart': _flutterWidgets,
  'flutter|lib/material.dart': _flutterMaterial,
  'router_builder|lib/router_builder.dart': _routerBuilder,
};

const String _flutterWidgets = '''
abstract class Widget {
  const Widget();
}

abstract class BuildContext {}

class SizedBox extends Widget {
  const SizedBox({this.child});
  final Widget? child;
}

abstract class Page<T> extends Widget {
  const Page();
}
''';

const String _flutterMaterial = '''
import 'widgets.dart';
export 'widgets.dart';

class MaterialPage<T> extends Page<T> {
  const MaterialPage({required this.child});
  final Widget child;
}
''';

// Mirrors the constructor and field shape of the real RouteInfo/RoutePolicy.
// `_path` is private on purpose: the generator reads it via
// `DartObject.getField('_path')`.
const String _routerBuilder = '''
import 'package:flutter/widgets.dart';

class RT {
  const RT();
}

class RTConfig {
  const RTConfig();
}

class RouteArgs {
  const RouteArgs();
}

typedef ScreenTitleBuilder = String Function(BuildContext, RouteArgs?);
typedef ScreenWidgetBuilder = Widget Function(BuildContext, RouteArgs?);
typedef ScreenPageBuilder = Page<dynamic> Function(BuildContext, RouteArgs?);
typedef RouterRedirect = String? Function(BuildContext, RouteArgs?);

class RoutePolicy {
  const RoutePolicy({
    this.mustBeAuthorized,
    this.pushGlobally,
    this.isPopupRoute,
    this.visibleNavBar,
    this.isTopLevelOnly,
    this.shouldReplaceAll,
    this.deepLinkAllowed,
    this.deepLinkPushGlobally,
  });

  final bool? mustBeAuthorized;
  final bool? pushGlobally;
  final bool? isPopupRoute;
  final bool? visibleNavBar;
  final bool? isTopLevelOnly;
  final bool? shouldReplaceAll;
  final bool? deepLinkAllowed;
  final bool? deepLinkPushGlobally;

  static const RoutePolicy global = RoutePolicy(pushGlobally: true);
  static const RoutePolicy public = RoutePolicy(mustBeAuthorized: false);
  static const RoutePolicy popup = RoutePolicy(isPopupRoute: true);
}

class RouteInfo {
  const RouteInfo(
    this.name, {
    this.title,
    this.builder,
    this.child,
    this.pageBuilder,
    this.redirect,
    this.deepLinkNames = const [],
    this.policy,
    String? path,
  })  : _path = path,
        isBranch = false,
        branchIndex = null,
        branchKey = null,
        branchParentType = null,
        forRedirectionOnly = false;

  const RouteInfo.redirect(
    this.name, {
    required this.redirect,
    this.title,
    this.deepLinkNames = const [],
    this.policy,
    String? path,
  })  : _path = path,
        builder = null,
        child = null,
        pageBuilder = null,
        isBranch = false,
        branchIndex = null,
        branchKey = null,
        branchParentType = null,
        forRedirectionOnly = true;

  const RouteInfo.branch(
    this.name, {
    required this.branchIndex,
    required this.branchKey,
    required this.branchParentType,
    this.title,
    this.child,
    this.builder,
    this.pageBuilder,
    this.deepLinkNames = const [],
    this.policy,
    String? path,
  })  : _path = path,
        isBranch = true,
        redirect = null,
        forRedirectionOnly = false;

  final String name;
  final bool forRedirectionOnly;
  final bool isBranch;
  final int? branchIndex;
  final String? branchKey;
  final Enum? branchParentType;
  final ScreenTitleBuilder? title;
  final ScreenWidgetBuilder? builder;
  final Widget? child;
  final ScreenPageBuilder? pageBuilder;
  final RouterRedirect? redirect;
  final List<String> deepLinkNames;
  final RoutePolicy? policy;
  final String? _path;

  String get path => _path ?? name;
}
''';

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

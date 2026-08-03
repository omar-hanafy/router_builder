import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

/// Mirrors go_router's `concatenatePaths`, which is what the router uses to
/// compute a nested route's full path at registration time. The tests below
/// pin [RouteInfo.location] to that algorithm so a location can never point
/// somewhere the tree does not register.
String concatenatePaths(String parentPath, String childPath) {
  final segments = <String>[
    ...parentPath.split('/'),
    ...childPath.split('/'),
  ].where((segment) => segment.isNotEmpty);
  return '/${segments.join('/')}';
}

const branch = RouteInfo.branch(
  'account',
  branchIndex: 0,
  branchKey: 'accountBranch',
  branchParentType: null,
  child: SizedBox(),
);

/// The regression case: name and public path deliberately disagree.
const prettyPath = RouteInfo(
  'app_settings',
  path: '/account-settings',
  child: SizedBox(),
);

const plain = RouteInfo('currencyScreen', child: SizedBox());

const parameterised = RouteInfo(
  'singleJob',
  path: '/singleJob/:id',
  child: SizedBox(),
  policy: RoutePolicy(pushGlobally: true),
);

const multiParam = RouteInfo(
  'thread',
  path: '/board/:boardId/thread/:threadId',
  child: SizedBox(),
  policy: RoutePolicy(pushGlobally: true),
);

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  group('location - top level', () {
    test('uses the declared path, not the name', () {
      expect(prettyPath.location(), '/account-settings');
    });

    test('falls back to /name when no path is declared', () {
      expect(plain.location(), '/currencyScreen');
    });

    test('hydrates :id from id', () {
      expect(parameterised.location(id: '42'), '/singleJob/42');
    });

    test('hydrates :id from pathParams', () {
      expect(
        parameterised.location(pathParams: const {'id': '7'}),
        '/singleJob/7',
      );
    });

    test('hydrates every parameter of a multi-parameter path', () {
      expect(
        multiParam.location(
          pathParams: const {'boardId': '3', 'threadId': '19'},
        ),
        '/board/3/thread/19',
      );
    });

    test('percent-encodes parameter values', () {
      expect(parameterised.location(id: 'a b/c'), '/singleJob/a%20b%2Fc');
    });

    test('appends query parameters', () {
      expect(
        plain.location(queryParams: const {'from': 'home'}),
        '/currencyScreen?from=home',
      );
    });

    test('an empty query map produces no trailing question mark', () {
      expect(plain.location(queryParams: const {}), '/currencyScreen');
    });
  });

  group('location - nested under a branch', () {
    test('uses the route NAME as the nested segment, never the path', () {
      // The whole point: /account/app_settings is registered,
      // /account/account-settings is not.
      expect(prettyPath.location(parentRoute: branch), '/account/app_settings');
      expect(
        prettyPath.location(parentRoute: branch),
        isNot(contains('account-settings')),
      );
    });

    test('nests a plain route under the branch path', () {
      expect(plain.location(parentRoute: branch), '/account/currencyScreen');
    });

    test('derives the parent segment from the parent path, not its name', () {
      const renamedBranch = RouteInfo.branch(
        'wallet',
        path: '/money',
        branchIndex: 1,
        branchKey: 'walletBranch',
        branchParentType: null,
        child: SizedBox(),
      );
      expect(
        plain.location(parentRoute: renamedBranch),
        '/money/currencyScreen',
      );
    });

    test('keeps query parameters when nested', () {
      expect(
        plain.location(parentRoute: branch, queryParams: const {'tab': '2'}),
        '/account/currencyScreen?tab=2',
      );
    });
  });

  group('location agrees with generatePath for every context', () {
    const routes = [prettyPath, plain, parameterised, multiParam];

    test('top-level location is exactly generatePath()', () {
      for (final route in routes) {
        final expected = route.generatePath();
        expect(
          route.location(
            id: '1',
            pathParams: const {'boardId': '1', 'threadId': '1'},
          ),
          // Same template, parameters filled.
          expected
              .replaceAll(':id', '1')
              .replaceAll(':boardId', '1')
              .replaceAll(':threadId', '1'),
          reason:
              'top-level location drifted from generatePath for '
              '${route.name}',
        );
      }
    });

    test('nested location is exactly concatenatePaths(parent, child)', () {
      for (final route in routes) {
        expect(
          route.location(parentRoute: branch),
          concatenatePaths(
            branch.generatePath(),
            route.generatePath(parentRoute: branch),
          ),
          reason:
              'nested location drifted from the registered path for '
              '${route.name}',
        );
      }
    });
  });

  group('missing path parameters', () {
    test('assert fires in debug', () {
      expect(() => parameterised.location(), throwsA(isA<AssertionError>()));
    });

    test('an empty id is treated as missing', () {
      expect(
        () => parameterised.location(id: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a partially filled multi-parameter path still asserts', () {
      expect(
        () => multiParam.location(pathParams: const {'boardId': '3'}),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('locationForArgs', () {
    test('threads id, pathParams and queryParams through', () {
      const args = RouteArgs(
        multiParam,
        pathParams: {'boardId': '3', 'threadId': '19'},
        queryParams: {'ref': 'push'},
      );
      expect(multiParam.locationForArgs(args), '/board/3/thread/19?ref=push');
    });

    test('nests when a parentRoute is supplied', () {
      const args = RouteArgs(prettyPath);
      expect(
        prettyPath.locationForArgs(args, parentRoute: branch),
        '/account/app_settings',
      );
    });
  });
}

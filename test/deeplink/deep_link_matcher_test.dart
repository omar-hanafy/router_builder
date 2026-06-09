import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  group('normalizeToAppPath host matching', () {
    test('accepts exact host and subdomains', () {
      expect(
        DeepLinkMatcher.normalizeToAppPath(
          Uri.parse('https://myapp.com/users/7'),
          hosts: ['myapp.com'],
        ).path,
        '/users/7',
      );
      expect(
        DeepLinkMatcher.normalizeToAppPath(
          Uri.parse('https://www.myapp.com/users/7'),
          hosts: ['myapp.com'],
        ).path,
        '/users/7',
      );
    });

    test('rejects look-alike substring hosts (security)', () {
      // evil-myapp.com is NOT allowed; the host is promoted to a path segment.
      expect(
        DeepLinkMatcher.normalizeToAppPath(
          Uri.parse('https://evil-myapp.com/users/7'),
          hosts: ['myapp.com'],
        ).path,
        '/evil-myapp.com/users/7',
      );
    });
  });

  group('match', () {
    test('resolves a template route and applies deepLinkPushGlobally', () {
      const route = RouteInfo('user', path: '/users/:id', child: SizedBox());
      final match = const DeepLinkMatcher().match(Uri.parse('/users/7'), const [
        route,
      ]);
      expect(match, isNotNull);
      expect(match!.args.id, '7');
      expect(match.args.effectivePushGlobally, isTrue);
    });

    test('honors a global deepLinkAllowed:false default (resolved gating)', () {
      RouterBuilderConfig.setDefaults(
        const RoutePolicy(deepLinkAllowed: false),
      );
      const route = RouteInfo('user', path: '/users/:id', child: SizedBox());
      final match = const DeepLinkMatcher().match(Uri.parse('/users/7'), const [
        route,
      ]);
      expect(match, isNull);
    });

    test('resolves redirect-only routes', () {
      const redirect = RouteInfo.redirect('gate', redirect: _to, path: '/gate');
      final match = const DeepLinkMatcher().match(Uri.parse('/gate'), const [
        redirect,
      ]);
      expect(match, isNotNull);
      expect(match!.route.name, 'gate');
    });
  });
}

String? _to(BuildContext c, RouteArgs? a) => null;

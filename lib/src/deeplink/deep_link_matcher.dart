import 'package:flutter/foundation.dart';
import 'package:router_builder/router_builder.dart';

/// Represents a successful deep link resolution.
@immutable
class DeepLinkMatch {
  /// Creates a deep link match with the resolved [route] and [args].
  const DeepLinkMatch({required this.route, required this.args});

  /// Route matched from the deep link.
  final RouteInfo route;

  /// Navigation arguments derived from the deep link.
  final RouteArgs args;
}

/// Utility that normalises incoming URIs and matches them against app routes.
class DeepLinkMatcher {
  /// Creates a stateless deep link matcher.
  const DeepLinkMatcher();

  /// Convert a deep link URI into an internal, path-only URI.
  ///
  /// * HTTPS URIs whose host appears in [hosts] keep their path/query.
  /// * Custom scheme URIs promote the host to the first segment.
  /// * Query parameters are preserved.
  static Uri normalizeToAppPath(
    Uri incoming, {
    Iterable<String> hosts = const [],
  }) {
    if (!incoming.hasScheme) {
      return incoming;
    }

    final lowerHosts = hosts.map((host) => host.toLowerCase());
    final scheme = incoming.scheme.toLowerCase();
    final params =
        incoming.queryParameters.isEmpty ? null : incoming.queryParameters;

    if ((scheme == 'http' || scheme == 'https') &&
        lowerHosts.any((host) => incoming.host.toLowerCase().contains(host))) {
      final path = incoming.path.isEmpty ? '/' : incoming.path;
      return Uri(path: path, queryParameters: params);
    }

    if (incoming.host.isEmpty) {
      final segments = incoming.pathSegments;
      final path = segments.isEmpty ? '/' : '/${segments.join('/')}';
      return Uri(path: path, queryParameters: params);
    }

    final segments = [incoming.host, ...incoming.pathSegments];
    return Uri(path: '/${segments.join('/')}', queryParameters: params);
  }

  /// Match a normalised URI against all [routes].
  ///
  /// Returns `null` if no route accepts the deep link.
  DeepLinkMatch? match(
    Uri appUri,
    Iterable<RouteInfo> routes, {
    Uri? original,
  }) {
    final effectiveRoutes = routes
        .where((route) => route.deepLinkAllowed)
        .toList(growable: false);
    final segments = appUri.pathSegments;

    if (segments.isEmpty) {
      for (final route in effectiveRoutes) {
        final templateSegments = _templateSegments(route.path);
        if (templateSegments.isEmpty) {
          return DeepLinkMatch(
            route: route,
            args: _buildArgs(route, appUri, original),
          );
        }
      }
    } else {
      for (final route in effectiveRoutes) {
        final templateSegments = _templateSegments(route.path);
        if (_matchesTemplate(segments, templateSegments)) {
          return DeepLinkMatch(
            route: route,
            args: _buildArgs(route, appUri, original),
          );
        }
      }

      final key = segments.first.toLowerCase();
      for (final route in effectiveRoutes) {
        final aliases = route.deepLinkNames.map((alias) => alias.toLowerCase());
        if (aliases.contains(key)) {
          return DeepLinkMatch(
            route: route,
            args: _buildArgs(route, appUri, original),
          );
        }
      }
    }

    return null;
  }

  RouteArgs _buildArgs(RouteInfo route, Uri uri, Uri? original) {
    final pushGlobally = route.resolvedPolicy.deepLinkPushGlobally!;
    return RouteArgs.fromUri(route, uri).copyWith(
      policy: RoutePolicy(pushGlobally: pushGlobally),
      object: original ?? uri,
    );
  }

  List<String> _templateSegments(String template) {
    var path = template;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.isEmpty) {
      return const [];
    }
    return path.split('/');
  }

  bool _matchesTemplate(List<String> incoming, List<String> template) {
    if (template.isEmpty) {
      return incoming.isEmpty;
    }
    if (incoming.length != template.length) {
      return false;
    }
    for (var i = 0; i < incoming.length; i++) {
      final expected = template[i];
      if (_isParam(expected)) continue;
      if (expected != incoming[i]) return false;
    }
    return true;
  }

  bool _isParam(String segment) =>
      segment.startsWith(':') && segment.length > 1;
}

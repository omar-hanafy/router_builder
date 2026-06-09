import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  test('package barrel exposes core types', () {
    const policy = RoutePolicy();
    expect(policy, isA<RoutePolicy>());
    const route = RouteInfo('home', child: SizedBox());
    expect(route.name, 'home');
    const args = RouteArgs(route);
    expect(args.route.name, 'home');
  });
}

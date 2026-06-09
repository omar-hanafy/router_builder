import 'package:flutter/material.dart';
import 'package:router_builder_example/routes.g.dart';

void main() {
  RoutesHelper.installDefaults();
  runApp(const ExampleApp());
}

/// Root widget of the example.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: HomeScreen());
}

/// Demonstrates the generated helper at runtime.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final match = RoutesHelper.resolveDeepLink(
      Uri.parse('https://example.com/items/42'),
      allowedHosts: const ['example.com'],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('router_builder example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total routes: ${RoutesHelper.allRoutes.length}'),
            Text('Global routes: ${RoutesHelper.globalRoutes.length}'),
            Text('Authorized routes: ${RoutesHelper.authorizedRoutes.length}'),
            Text('Redirect routes: ${RoutesHelper.redirectRoutes.length}'),
            Text('Branches: ${RoutesHelper.allBranches().length}'),
            Text(
              'Deep link -> ${match?.route.name ?? 'none'} '
              '(id=${match?.args.id})',
            ),
          ],
        ),
      ),
    );
  }
}

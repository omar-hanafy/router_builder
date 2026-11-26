# Generate a route for a Flutter app

Use this example with `router_builder` 4.x. Add `router_builder` to the app's
dependencies and `router_builder_generator` and `build_runner` to its
dev dependencies.

In `lib/app_routes.dart`, define a route and give it a path parameter.

```dart
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

@RT()
const details = RouteInfo(
  'details',
  path: '/items/:id',
  child: SizedBox(),
);
```

Run the builder from the app directory.

```sh
dart run build_runner build
```

Import the generated file to look up the typed route or match an incoming URI.

```dart
import 'routes.g.dart';

void checkRoutes() {
  RoutesHelper.installDefaults();
  final match = RoutesHelper.resolveDeepLink(
    Uri.parse('https://example.com/items/42'),
    allowedHosts: const ['example.com'],
  );
  assert(match?.route == Routes.details);
  assert(match?.args.id == '42');
}
```

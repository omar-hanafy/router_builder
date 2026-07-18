A Flutter app depends on router_builder 2.0.4 and contains code like:

```dart
import 'package:router_builder/models/models.dart';

@RT()
static const admin = RouteInfo(
  'admin',
  child: AdminPanel(),
  isGlobalOnly: true,
  mustBeAuthorized: true,
);

class DialogArgs extends RouteArgs {
  const DialogArgs(super.route, {super.pushGlobally, super.isIdSlug});
}

void main() {
  RouterBuilderConfig.setDefaults(mustBeAuthorized: false);
  runApp(const App());
}
```

Navigation code reads `route.isGlobalOnly ?? false` and imports
`route_info_helper.dart` using `MyRoutes` and `RouteInfoHelper`.

The team wants to upgrade to router_builder 3.x. Lay out the complete
migration plan: what is automated (and by what), every category of manual
change this snippet needs with the exact v3 replacements, what to regenerate,
and which behavioral changes to audit afterward. Answer in prose + short code;
no need to run anything.

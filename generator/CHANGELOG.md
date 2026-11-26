# CHANGELOG

## 4.0.0

- First standalone release of the builder previously bundled with
  `router_builder` 3.x. Use it in `dev_dependencies` alongside the 4.x
  runtime. The builder generates typed routes, branch maps, policy setup and
  deep-link helpers in `lib/routes.g.dart`.
- Supports build 4.0.6 through 5.x and analyzer 13.x through 14.x.
  Regeneration requires Dart 3.11 or later.
- Custom build configurations use the
  `router_builder_generator:generate_route_info_helper` key. For direct
  builder imports and exports, run `dart fix --apply` after upgrading both
  packages, or replace the old URI with
  `package:router_builder_generator/builder.dart`.

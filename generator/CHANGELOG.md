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
  builder imports and exports, preview
  `dart run router_builder_generator:migrate_builder_imports` after upgrading
  both packages, then add `--write` to apply the URI changes. The command
  preserves prefixes, combinators and conditional directives. Data-driven
  `dart fix` transforms also cover unprefixed builder references.

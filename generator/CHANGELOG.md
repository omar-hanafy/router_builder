# CHANGELOG

## 4.0.0

Initial release. This package holds the code generator that shipped inside
`router_builder` up to 3.x; it starts at 4.0.0 so its major version tracks the
runtime package it generates for.

- Provides the `generate_route_info_helper` builder, which scans `lib/` for
  `@RT` routes and `@RTConfig` and emits `lib/routes.g.dart`. Behaviour and
  output are unchanged from `router_builder` 3.1.0.
- Depends on `analyzer >=13.0.0 <15.0.0`. Migrated to the analyzer 13 AST:
  `NamedExpression` -> `NamedArgument`, `Label.label` -> the `Token` on
  `Label.name`, and `ArgumentList.arguments` now yields `Argument` rather than
  `Expression`.
- Pure Dart, with no `flutter` dependency. Flutter pins `meta` to an exact
  version, which caps `analyzer` below 13.1.0; staying Flutter-free is what
  lets this package resolve - and be tested against - the newest analyzer.
- `source_gen` is not used and is not a dependency.

Add it to `dev_dependencies`, never to `dependencies`:

```yaml
dependencies:
  router_builder: ^4.0.0
dev_dependencies:
  router_builder_generator: ^4.0.0
```

See [the migration guide](https://github.com/omar-hanafy/router_builder/blob/main/MIGRATION_GUIDE.md#v3---v4)
for the v3 -> v4 upgrade.

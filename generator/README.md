# router_builder_generator

Build-time code generator for [`router_builder`](https://pub.dev/packages/router_builder).

It scans your `lib/` for `@RT`-annotated `RouteInfo` declarations and a single
`@RTConfig` policy, then emits `lib/routes.g.dart` with typed route constants,
branch maps, category getters, and a deep-link table.

## Install

This package is build-time only. Put it in `dev_dependencies` — never in
`dependencies`.

```yaml
dependencies:
  router_builder: ^4.0.0

dev_dependencies:
  build_runner: ^2.15.0
  router_builder_generator: ^4.0.0
```

Then:

```bash
dart run build_runner build
```

## Why it is a separate package

Up to `router_builder` 3.x the generator lived in the runtime package, which
meant `analyzer`, `build`, and `dart_style` were declared as regular
`dependencies`. Pub had to resolve them for every consuming app even though no
app code imported them — so `router_builder`'s `analyzer` upper bound capped
what those apps could upgrade `build_runner`, `build`, and `dart_style` to, and
passed that cap on transitively to anything depending on them.

Splitting the generator out puts it behind a `dev_dependency`, and
`dev_dependencies` are not transitive. The runtime package now depends only on
`flutter`, `dart_helper_utils`, and `equatable`.

This package is deliberately **pure Dart**. Flutter pins `meta` to an exact
version, which caps `analyzer` below 13.1.0; staying Flutter-free is what lets
the generator resolve, and be tested against, the newest analyzer.

## Configuration

Options go in your app's `build.yaml`:

```yaml
targets:
  $default:
    builders:
      router_builder_generator:generate_route_info_helper:
        options:
          route_class_name: Routes        # generated route-constants class
          helper_class_name: RoutesHelper # generated helper class
          output: lib/routes.g.dart       # output path
          fail_on_conflict: true          # fail the build on deep-link key clashes
```

## Documentation

Route definition, policies, and deep linking are documented in the
[`router_builder` README](https://github.com/omar-hanafy/router_builder#readme).
Upgrading from 3.x is covered in the
[migration guide](https://github.com/omar-hanafy/router_builder/blob/main/MIGRATION_GUIDE.md#v3---v4).

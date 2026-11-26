# router_builder_generator

Generates typed route constants, branch lookups and deep-link helpers from
`@RT()` declarations in a Flutter app. The generator runs on the Dart VM
during development. Your app uses the generated Dart file at runtime.

## Install

Use the generator with `router_builder` 4.x. Version 3.x of the runtime
includes its own builder. Regeneration requires Dart 3.11 or later and a
Flutter dependency resolution that supports analyzer 13 or 14.

```yaml
dependencies:
  router_builder: ^4.0.0

dev_dependencies:
  build_runner: ^2.15.0
  router_builder_generator: ^4.0.0
```

Run these commands from the app directory.

```sh
flutter pub get
dart run build_runner build
```

The builder scans the app's `lib/` for annotated top-level declarations and
public static fields. It writes `lib/routes.g.dart` and uses an optional
`@RTConfig()` policy for `RoutesHelper.installDefaults()`. The generator has
its own Dart dependencies. An app that ships generated routes can depend
solely on the runtime for routing.

[Example with a route, generated lookup and deep-link match](example/README.md)

## Configuration

Set options in the consuming app's `build.yaml`. These are the defaults.

```yaml
targets:
  $default:
    builders:
      router_builder_generator:generate_route_info_helper:
        options:
          route_class_name: Routes
          helper_class_name: RoutesHelper
          output: lib/routes.g.dart
          fail_on_conflict: true
```

With `fail_on_conflict: true`, the build fails when routes share a name,
first path segment or deep-link alias. With `false`, the builder logs a
warning and keeps the first entry for the conflicting key.

## Upgrading from the bundled 3.x builder

1. Move to `router_builder` 4.x and add the dev dependencies above.
2. In custom build configuration, replace
   `router_builder:generate_route_info_helper` with
   `router_builder_generator:generate_route_info_helper`.
3. For a direct builder import or export, use
   `package:router_builder_generator/builder.dart`. After resolving the
   paired 4.x packages, run `dart fix --dry-run` to preview Dart directive
   migrations and `dart fix --apply` to apply them. Update builder import
   strings in YAML manually.
4. Regenerate the routes and run your app's analyzer and tests.

Application annotations and models keep their
`package:router_builder/router_builder.dart` import.

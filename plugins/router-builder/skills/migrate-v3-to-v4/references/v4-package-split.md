# router_builder v4: the generator package split

Reference for the `migrate-v3-to-v4` skill. Statements here describe v4 as
shipped; verify against the package sources before changing them.

## What actually changed

| | v3 | v4 |
|---|---|---|
| Runtime package | `router_builder` | `router_builder` (unchanged import) |
| Generator location | inside `router_builder` | `router_builder_generator` |
| Builder entrypoint | `package:router_builder/builder.dart` | `package:router_builder_generator/builder.dart` |
| `build.yaml` key | `router_builder:generate_route_info_helper` | `router_builder_generator:generate_route_info_helper` |
| Where the generator is declared | `dependencies` | `dev_dependencies` |
| `analyzer` | `>=9.0.0 <13.0.0` | `>=13.0.0 <15.0.0` |
| `source_gen` | declared (never used) | removed |
| Runtime deps | flutter, dart_helper_utils, equatable, analyzer, build, dart_style, glob, source_gen | flutter, dart_helper_utils, equatable |

Unchanged: `RouteInfo`, `RoutePolicy`, `RouteArgs`, `@RT`, `@RTConfig`,
`DeepLinkHandler`, `RouterBuilderConfig`, the generated `routes.g.dart` API,
and the single barrel import
`package:router_builder/router_builder.dart`.

## Why the split was necessary

Up to 3.x, `router_builder` declared `analyzer`, `build`, `dart_style`,
`glob`, and `source_gen` as regular `dependencies`. The generator's *code* was
already kept out of the runtime barrel, so no app ever imported those
packages - but that only governs imports, not resolution. Pub still had to
solve them for every consumer.

Two consequences, and both are what "router_builder is blocking my upgrade"
means in practice:

1. `router_builder`'s `analyzer` upper bound capped the app's whole build
   chain. With `analyzer <13.0.0` pinned by the runtime package, `build_runner`
   could not advance to a release requiring `analyzer >=13.3.0`, and neither
   could `build` or `dart_style`.
2. Regular dependencies are transitive. A package depending on
   `router_builder` passed the same cap down to every app depending on *it*,
   with no way for that app to opt out.

`dev_dependencies` are not transitive, so moving the generator behind one
removes the cap structurally rather than by widening a bound every time the
ecosystem publishes a new analyzer major.

## SDK compatibility

The generator's pubspec declares its Dart and analyzer ranges. Flutter 3.44.x
pins `meta` at 1.18.0 and can resolve analyzer 13.0.0. Inspect the actual
Flutter release and the solver output when diagnosing a different graph. A
consumer that uses only the runtime avoids the generator's dependencies.

## Applying the migration

`scripts/migrate_to_v4.sh` is the same executable as `tool/migrate_to_v4.sh`.
It uses Ruby's standard YAML parser to preview edits and applies them with
`--write`. It finds the runtime under a package's direct dependencies before
editing the manifest or sibling `build.yaml`.

- Ordinary v3 exact, caret and bounded hosted constraints become `^4.0.0`.
  An existing v4 constraint is retained. For packages that declare
  `build_runner`, the script adds a missing generator as a dev dependency.
  Runtime-only packages can upgrade independently.
- It rewrites the old fully qualified builder key in targets, global options,
  `applies_builders` and `runs_before`, plus explicit builder import URIs.
- Review custom sources, constraints and overrides manually. A published
  builder that exposes the generator from `lib/` needs a normal dependency.
- After `flutter pub get`, preview
  `dart run router_builder_generator:migrate_builder_imports` and repeat with
  `--write`. It updates complete directives, including prefixed, conditional
  and `show` imports and re-exports. You can also replace the URI by hand.
  `dart fix` independently supports unprefixed references and may leave other
  forms incomplete. The runtime barrel stays at
  `package:router_builder/router_builder.dart`.

Run `dart run build_runner build` and review the generated routes. An updated
formatter can produce different line wraps.

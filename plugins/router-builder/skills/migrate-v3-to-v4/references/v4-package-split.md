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

## The Flutter SDK floor (the part that surprises people)

`analyzer >=13.1.0` requires `meta ^1.18.3`. The Flutter SDK pins `meta` to an
**exact** version in both `packages/flutter` and `packages/flutter_test`, so
the installed Flutter decides which analyzer versions are reachable at all.

- Flutter 3.44.x pins `meta 1.18.0` -> analyzer 13.0.0 is the ceiling.
- Older Flutter pins something below 1.18.0 -> analyzer 13 is unreachable, so
  v4's generator cannot be resolved at all.

This is why v4's floor is `13.0.0` and not `13.3.0`: a `13.3.0` floor would
lock out current Flutter stable.

Diagnosing a failed solve: the message names the pinned package, e.g.
"every version of flutter from sdk depends on meta 1.18.0 and analyzer
>=13.1.0 depends on meta ^1.18.3". That is an SDK-version problem. The fix is
upgrading Flutter or staying on router_builder 3.x - never a
`dependency_overrides` entry, which produces a graph the packages never
declared support for.

## What the codemod does and does not touch

`scripts/migrate_to_v4.sh` (byte-identical to `tool/migrate_to_v4.sh` in the
package repo) is dry-run by default and idempotent.

Rewrites:

- hosted `router_builder:` constraint in any `pubspec.yaml` -> `^4.0.0`
- inserts `router_builder_generator: ^4.0.0` into `dev_dependencies`, creating
  the block if absent
- `router_builder:generate_route_info_helper` ->
  `router_builder_generator:generate_route_info_helper` in any `build.yaml`

Leaves alone:

- a `path:`/`git:` `router_builder` dependency, because rewriting the
  constraint line would orphan the source lines beneath it
- all Dart sources - v4 changes no runtime API
- dependency ordering; the new entry is inserted first in the block, which
  trips `sort_pub_dependencies` if that lint is enabled

## Expected post-migration diffs

- `routes.g.dart`: **formatting only**. v4 resolves `dart_style` 3.1.9+, which
  wraps chained calls differently from 3.1.8. Route data must be identical; a
  content change means something else went wrong.
- `pubspec.lock`: for an app that does not regenerate, `analyzer`, `build`,
  and `dart_style` disappear from the graph entirely.

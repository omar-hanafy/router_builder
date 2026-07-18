# Generator reference (router_builder v3)

Verified against `lib/src/generators/generate_route_info_helper.dart` and the
package `build.yaml` at v3.0.x.

## What the builder is

One aggregating builder (`generateRouteInfoHelperBuilder`, exported from
`package:router_builder/builder.dart`) that scans every resolvable library
under the consuming package's `lib/**.dart` and writes ONE output file.
It ships with `auto_apply: dependents` and `build_to: source`, so a consumer
app needs NO build.yaml at all for default behavior. Run:

```bash
dart run build_runner build
# or during development
dart run build_runner watch
```

Current build_runner (2.15+) handles conflicting outputs automatically and
IGNORES the legacy `--delete-conflicting-outputs` flag ("removed option").
Only add that flag when the project resolves an older build_runner that still
prompts about conflicting outputs.

## Discovery rules (what `@RT` finds)

Scanned:
- PUBLIC STATIC fields of classes (any class, including `abstract`).
- PUBLIC TOP-LEVEL `const`/`final` variables.

Not scanned: private members (leading `_`), instance fields, enum members,
mixins, extensions, files outside `lib/`, and part files that fail to resolve
as libraries. A route that "does not show up" is almost always private,
non-static, outside `lib/`, or missing the `@RT()` annotation.

`@RTConfig` follows the same discovery rules and must annotate a
`const RoutePolicy`; exactly one per package.

## Builder options

Override in the CONSUMER app's `build.yaml`:

```yaml
targets:
  $default:
    builders:
      router_builder|generate_route_info_helper:
        options:
          output: lib/routes.g.dart          # also update build_extensions if you fully redefine the builder
          route_class_name: Routes
          helper_class_name: RoutesHelper
          fail_on_conflict: true
```

| Option | Default | Effect |
|---|---|---|
| `output` | `lib/routes.g.dart` | Output asset path (package-root relative). |
| `route_class_name` | `Routes` | Name of the generated constants class. |
| `helper_class_name` | `RoutesHelper` | Name of the generated helper class. |
| `fail_on_conflict` | `true` | Deep-link key conflict fails the build; `false` logs a warning and keeps the first claimant. |

v2-era projects that pinned old names use
`output: lib/route_info_helper.dart`, `route_class_name: MyRoutes`,
`helper_class_name: RouteInfoHelper`.

## Generated output shape

- Header `// GENERATED CODE - DO NOT MODIFY BY HAND.` and
  `// ignore_for_file: type=lint`. Never hand-edit; regenerate.
- Imports: `dart_helper_utils`, the `router_builder` barrel, then every
  consumer library that declares a route/config, PREFIXED `_i0`, `_i1`, ... in
  sorted-URI order (prefixes prevent identifier collisions).
- `abstract class Routes`: one `static const|final RouteInfo <ident> = _iN.Ref;`
  per route. `const` is preserved from the declaration. The identifier is the
  ROUTE NAME made safe: characters outside `[a-zA-Z0-9_]` become `_` (so the
  hierarchical name `settings.profile` becomes `settings_profile`), and a
  leading digit gets a `_` prefix. Two routes with the same name generate
  duplicate class members and break compilation, in addition to the deep-link
  key conflict below.
- `abstract class RoutesHelper`:
  - `branches`: `Map<ShellEnum, Map<int?, RouteInfo>>` grouped by
    `branchParentType` value, ordered by `branchIndex`.
  - `<enumValue>Branches` list per shell value.
  - `allRoutes`: branches first, then every non-branch annotated route
    (INCLUDING redirect-only routes).
  - Runtime category getters (`normalRoutes`, `globalRoutes`, `popupRoutes`,
    `topLevelRoutes`, `authorizedRoutes`, `redirectRoutes`) computed from
    resolved policy getters on each access.
  - `deepLinkMap`, `fromName`, `resolveDeepLink`, `normalizeToAppPath`,
    `branchesFor`, `allBranches`, `branchByIndex`, `isRouteInShell`,
    `branchByKey`, `installDefaults`.

## Build-failure catalog (RouterBuilderError)

| Message starts with | Cause | Fix |
|---|---|---|
| `Found N @RTConfig declarations (...). Exactly one is allowed.` | Multiple `@RTConfig` | Keep one; delete or un-annotate the rest. |
| `@RTConfig on "X" must annotate a `const RoutePolicy`.` | Non-const target | Make the variable `const`. |
| `@RTConfig on "X" must be a RoutePolicy (found T).` | Wrong type | Annotate a `RoutePolicy` value. |
| `Deep-link key conflict(s): ...` | Two routes share a key (name, first path segment, or alias) | Rename route / change path / adjust `deepLinkNames`; `fail_on_conflict: false` only downgrades to a warning. |
| `branchParentType for X must be an enum value.` | Non-enum discriminator | Use an enum value. |
| `All branch routes must share a single branchParentType enum type.` | Two shells use two different enums | One enum type across ALL branch routes (different VALUES of that enum define the shells). |

A route name that is not a plain string literal or const (e.g. computed at
runtime) cannot be extracted; keep `RouteInfo` names as literals.

## Troubleshooting sequence

1. `dart run build_runner build` and READ the error; `RouterBuilderError`
   messages name the offending declarations.
2. Output stale or missing with no error: `dart run build_runner clean`, then
   build again. Check the file was not excluded by a custom `build.yaml`.
3. Route missing from output: check discovery rules above (private? instance?
   outside lib/? annotation import correct?).
4. `Conflicting outputs` prompt (older build_runner only): rerun with
   `--delete-conflicting-outputs`.
5. Dependency solve failures mentioning `analyzer`, `build`, `source_gen`, or
   `dart_style`: router_builder 3.0.1+ allows `analyzer >=9.0.0 <13.0.0`.
   Find the package pinning an incompatible range (`dart pub deps` or read the
   solver output), upgrade it, and only use `dependency_overrides` as a
   last-resort diagnostic, never a shipped fix.
6. Generated file has analyzer warnings in the IDE: the file starts with
   `ignore_for_file: type=lint`; project analysis_options that exclude
   `**/*.g.dart` are the conventional companion.

## Package-repo test note (maintainers)

Generator tests in THIS repo are tagged `generator` and skipped under
`flutter test` (build_test needs the Dart VM runner). Run them with:

```bash
dart test --run-skipped test/generator/
```

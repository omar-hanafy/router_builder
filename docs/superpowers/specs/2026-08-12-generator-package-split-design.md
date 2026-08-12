# router_builder v4: generator package split

**Date:** 2026-08-12
**Status:** implemented
**Goal:** `router_builder` must never be the package that blocks a Flutter app
from upgrading its dependency graph.

## Problem

`router_builder` 3.x declared `analyzer`, `build`, `dart_style`, `glob`, and
`source_gen` as regular **`dependencies`**.

`lib/builder.dart` carried a comment claiming this kept those packages away
from consumer apps. That was true of *imports* and tree-shaking, and false of
*resolution*: pub's solver still had to satisfy every one of them for every
consumer. Two measured consequences:

1. **Direct capping.** With `analyzer <13.0.0` in the runtime package, an app
   could not advance `build_runner` past 2.15.1, `build` past 4.0.7, or
   `dart_style` past 3.1.8 — all of which require `analyzer >=13.3.0` in their
   newer releases.
2. **Transitive leakage.** Regular dependencies are transitive, so any package
   depending on `router_builder` handed the same cap to every app depending on
   *it*, with no opt-out.

A second, latent defect was found while investigating: the working tree
carried an uncommitted widening to `analyzer <15.0.0`, but the generator used
`NamedExpression` and `Label.label`, both **removed in analyzer 13.0.0**. The
package's own test suite could never catch this, because `test ^1.25.0` plus
`flutter_test`'s exact `test_api 0.7.11` pin held the dev resolution below
analyzer 13. Publishing that bound would have broken every consumer whose SDK
allowed analyzer 13+.

## Root cause

The generator and the runtime shared one package, so they shared one
dependency graph and one resolution. Everything else follows from that.

## Decision

Split into two packages, released in lockstep at 4.0.0:

| Package | Location | Nature | Dependencies |
|---|---|---|---|
| `router_builder` | repo root | Flutter runtime | `flutter`, `dart_helper_utils`, `equatable` |
| `router_builder_generator` | `generator/` | **pure Dart** build-time | `analyzer >=13.0.0 <15.0.0`, `build`, `dart_style`, `glob` |

Consumers keep `router_builder` in `dependencies` and add
`router_builder_generator` to `dev_dependencies`. Dev dependencies are not
transitive, so the cap is removed *structurally* rather than by widening a
bound each time the ecosystem moves.

### Rejected: Pub workspace

Workspace members share a single resolution. The generator would inherit
Flutter's exact `meta` pin and be capped below analyzer 13.1.0 — the exact
problem being solved. Each package keeps an independent lockfile instead.

### Rejected: move deps to `dev_dependencies` in one package

Dev dependencies are not transitive, so `build_runner` in a consumer could not
resolve the builder's imports. Unsound.

### Why the analyzer floor is 13.0.0, not 13.3.0

`analyzer >=13.1.0` requires `meta ^1.18.3`. Flutter pins `meta` **exactly**
(1.18.0 in Flutter 3.44.9, in both `packages/flutter` and
`packages/flutter_test`). A 13.3.0 floor would lock out current Flutter
stable. 13.0.0 is the newest analyzer reachable today, and the range stays open
to 14.x for future SDKs.

Consequence: regenerating with v4 requires **Flutter 3.44+**. The runtime
package alone carries no such floor.

## Implementation

### Analyzer 13 AST migration

Three API changes, all in `_positionalExpr`/`_namedExpr`:

| analyzer 12 | analyzer 13+ |
|---|---|
| `NamedExpression` | `NamedArgument` |
| `arg.name.label.name` (`Label.label`, a `SimpleIdentifier`) | `arg.name.lexeme` (`NamedArgument.name` is a `Token`) |
| `arg.expression` | `arg.argumentExpression` |
| `ArgumentList.arguments` → `NodeList<Expression>` | `NodeList<Argument>` |

Positional arguments are selected with `arg is Expression`, because
`Expression implements Argument` while `NamedArgument` does not. Verified
against the analyzer 13.0.0 and 14.1.0 sources directly — the changelog's
description of `Label` was misleading; `NamedArgument.name` is a bare `Token`,
not a `Label`.

### Test harness

Generator tests previously called `TestReaderWriter.testing.loadIsolateSources()`,
copying real Flutter and router_builder sources off disk. That required a
Flutter dependency, which would re-impose the `meta` pin and make the declared
analyzer range untestable.

Replaced with stub package sources (`flutter/widgets.dart`,
`flutter/material.dart`, `router_builder/router_builder.dart`) seeded into the
reader via `testing.writeString`. The generator only inspects the resolved
element model — constructor names, field names, enum-ness — so stubs suffice.

Fixtures build under a separate root package (`example_app`) and the stubs are
seeded into the reader rather than passed as `sourceAssets`, because the
aggregating builder would otherwise run once per package in the asset graph.

Real-Flutter coverage moves to `example/`, which builds against the actual
runtime package in CI.

Side effect: the suite went from ~35s to under 1s.

### Verification

`tool/test_analyzer_matrix.sh` runs the generator suite at both ends of the
declared range. Both pass:

- floor: analyzer 13.0.0, build 4.0.7, dart_style 3.1.9
- ceiling: analyzer 14.1.0, build 4.0.10, dart_style 3.1.12

CI runs this as a matrix and additionally asserts that `analyzer`, `build`,
`dart_style`, `source_gen`, and `glob` are absent from the runtime package's
`pubspec.lock` — the invariant this release exists to hold.

### Publishing

`example/` ships inside the `router_builder` archive, so it depends on the
generator by **hosted** version; `example/pubspec_overrides.yaml` (excluded via
`.pubignore`) points at the local sibling for development. `generator/` is
excluded from the runtime archive.

**Publish order: `router_builder_generator` first, then `router_builder`**, so
pana can resolve the bundled example.

## Results

- Runtime resolution: ~90 packages → **32**; `analyzer`, `build`, `dart_style`
  gone entirely.
- `source_gen` dropped — it was declared but never imported.
- No runtime API change. No Dart source change for consumers. The migration is
  a pubspec edit, automated by `tool/migrate_to_v4.sh`.
- Generated `routes.g.dart` changes only in whitespace (dart_style 3.1.8 →
  3.1.9 wraps chained calls differently).

## Follow-ups

- When Flutter stable ships `meta >=1.18.3`, analyzer 13.1+/14.x becomes
  reachable for consumers; no package change is needed, since the range
  already allows it and CI already tests 14.1.0.
- The `analyzer` floor should only rise when a Flutter release ships the
  required `meta`, and that raise is a breaking change (documented Flutter
  floor).

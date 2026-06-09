# Router Builder v3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship router_builder 3.0.0 - one comprehensive `RoutePolicy`, runtime-derived (drift-proof) generated artifacts, an encapsulated `lib/src/` layout, a configurable generator, a safe deep-link layer, JSON-safe diagnostics, a first test suite, and a runnable example.

**Architecture:** Resolution is one `merge` fold (`args.policy` -> `route.policy` -> `RouterBuilderConfig.defaults`, then branch/redirect structural constraints applied last). The generator emits only statically-true data (`allRoutes`, `Routes` constants, branch map, `deepLinkMap`) and derives behavior categories at runtime via the resolved getters, so the generated file can never report stale values. Public API is a single barrel; everything else lives under `lib/src/`.

**Tech Stack:** Dart/Flutter package; `analyzer` 10.2.0, `build` 4.0.6, `source_gen` 4.2.3, `build_runner` 2.15.0, `dart_style` 3.1.7, `dart_helper_utils` 6.0.2 (re-exports `convert_object` `toJsonMap`/`JsonOptions`), `equatable` 2.0.8. Tests: `flutter_test` + `build_test` + `test`.

**Spec:** `/Users/omarhanafy/Development/MyProjects/router_builder/docs/superpowers/specs/2026-06-09-router-builder-v3-design.md` (decisions D1-D17).

---

## Context

`RoutePolicy` (1.2.0) grouped route behavior, but flat fields were kept and deprecated (2.1.0) with resolution logic duplicated across `RouteInfo.localPolicy`, `RouteArgs.localPolicy`, the `effectiveX` getters, `RouterBuilderConfig.setDefaults`, and the generator. A full read surfaced more: the generated file can report false categories (it bakes values the build step cannot soundly know, since global defaults are installed at runtime in `main()`); there is no `lib/src/` encapsulation (every file is deep-importable); the generator ignores `BuilderOptions` and hardcodes class names and output path; deep-link host matching uses substring `.contains()` (a security footgun: `evil-myapp.com` matches `myapp.com`); redirect-only routes are missing from `allRoutes`; and there are no tests and no example.

v3 is the one cheap breaking-change window. The user wants the FULL v3 (all breaking changes), built additive-foundation-first so each commit compiles and is tested, then a final breaking sweep. This plan delivers the complete 3.0.0.

## Locked decisions (O1-O5 + the two scope answers)

- **O1** Default `duplicateBehavior` = `DuplicateRouteBehavior.duplicate`.
- **O2** `DuplicateRouteBehavior` split into its own file `lib/src/models/duplicate_route_behavior.dart`.
- **O3 / Constraints** Branch/redirect structural constraints: **force + debug `assert`** (always enforce the structural value; in debug, assert when a policy conflicts). Confirmed by user.
- **O4** `RouterBuilderConfig.setDefaults(RoutePolicy)` only (no per-field wrapper; `RoutePolicy(...)` already provides named params).
- **O5** Runtime category getters recompute per access (route counts are small).
- **Example** Include a minimal runnable `example/` AND a comprehensive generator fixture that exercises every supported case exactly once (full non-repetitive generated golden + smoke test).

## Branch / redirect constraint table (authoritative; reconciles spec sections 6 and 10)

| Route kind | Forced (constrain overrides) | Free via policy |
|------------|------------------------------|-----------------|
| `branch` | `pushGlobally=false`, `isPopupRoute=false`, `deepLinkPushGlobally=false` | `mustBeAuthorized`, `duplicateBehavior`, `visibleNavBar`, `isTopLevelOnly`, `deepLinkAllowed`, `shouldReplaceAll` |
| `redirect` (`forRedirectionOnly`) | `isPopupRoute=false`, `visibleNavBar=false`, `shouldReplaceAll=false` | `mustBeAuthorized`, `pushGlobally`, `duplicateBehavior`, `isTopLevelOnly`, `deepLinkAllowed`, `deepLinkPushGlobally` |
| standard | none | all |

`deepLinkPushGlobally=false` is forced for branches so a deep-linked tab lands in its shell (spec section 10).

---

## Final file structure

```
lib/
  router_builder.dart        # public runtime barrel (only runtime import)
  builder.dart               # build entrypoint: re-exports generateRouteInfoHelperBuilder
  src/
    annotations/route.dart            # RT, RTConfig
    models/duplicate_route_behavior.dart
    models/route_policy.dart
    models/route_info.dart
    models/route_args.dart
    router_config.dart
    deeplink/deep_link_matcher.dart
    handlers/deep_link_handler.dart
    generators/generate_route_info_helper.dart
test/
  smoke_test.dart
  models/duplicate_route_behavior_test.dart
  models/route_policy_test.dart
  models/router_config_test.dart
  models/route_info_test.dart
  models/route_args_test.dart
  resolution_matrix_test.dart
  deeplink/deep_link_matcher_test.dart
  generator/generator_options_test.dart
  generator/generator_discovery_test.dart
  generator/generator_output_test.dart
  generator/generator_conflict_test.dart
  generator/generator_rtconfig_test.dart
  generator/generator_golden_test.dart
  generator/_support.dart            # shared testBuilder helpers + fixture sources
example/
  pubspec.yaml
  analysis_options.yaml              # relaxes public_member_api_docs for the demo
  build.yaml
  lib/routes/app_routes.dart         # every supported @RT case once + @RTConfig
  lib/routes.g.dart                  # generated (committed golden)
  lib/main.dart
```

Notes:
- `router_builder.dart` exports only runtime API; it does NOT export the generator (which pulls in `analyzer`/`build`/`dart_style`).
- Internal `src/` files import each other with `package:router_builder/src/...` (the repo lints `always_use_package_imports: error`, `avoid_relative_lib_imports: error`).
- `public_member_api_docs: error` is on - EVERY public member in `lib/` needs a `///` doc comment. All code below includes them; do not drop them.
- The generated `*.g.dart` is excluded from analysis, so it is exempt from the doc lint.

---

## Phase 0 - Test harness and dependencies

### Task 0.1: Add test deps, bump version, prove `flutter test` runs

**Files:**
- Modify: `pubspec.yaml`
- Create: `test/smoke_test.dart`

- [ ] **Step 1: Add dev dependencies and bump version**

In `pubspec.yaml` set `version: 3.0.0` and add to `dev_dependencies` (keep existing, keep alphabetical for `sort_pub_dependencies`):

```yaml
version: 3.0.0
```

```yaml
dev_dependencies:
  build_runner: ^2.13.1
  build_test: ^3.5.0
  flutter_lints: ^6.0.0
  flutter_test:
    sdk: flutter
  test: ^1.25.0
```

- [ ] **Step 2: Write a smoke test that imports the barrel**

`test/smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  test('package barrel exposes core types', () {
    const policy = RoutePolicy();
    expect(policy, isA<RoutePolicy>());
    const route = RouteInfo('home', child: SizedBox());
    expect(route.name, 'home');
    const args = RouteArgs(route);
    expect(args.route.name, 'home');
  });
}
```

- [ ] **Step 3: Resolve deps and run the smoke test**

Run: `cd /Users/omarhanafy/Development/MyProjects/router_builder && flutter pub get && flutter test test/smoke_test.dart`
Expected: PASS (1 test). If `SizedBox` is unresolved, add `import 'package:flutter/widgets.dart';` to the test.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock test/smoke_test.dart
git commit -m "test: add build_test/test deps, smoke test, bump to 3.0.0"
```

---

## Phase 1 - Package layout (D10)

### Task 1.1: Move sources under `lib/src/`, add single barrel and `builder.dart`

Mechanical move with no behavior change. The public barrel path (`package:router_builder/router_builder.dart`) stays stable, so tests are unaffected.

**Files:**
- Move (git mv): all of `lib/annotations/`, `lib/deeplink/`, `lib/handlers/`, `lib/models/route_*.dart`, `lib/router_config.dart`, `lib/generators/` into `lib/src/...` (see final structure).
- Delete: `lib/models/models.dart`.
- Modify: `lib/router_builder.dart` (barrel), `build.yaml`.
- Create: `lib/builder.dart`.

- [ ] **Step 1: Move files**

```bash
cd /Users/omarhanafy/Development/MyProjects/router_builder
mkdir -p lib/src/annotations lib/src/deeplink lib/src/handlers lib/src/models lib/src/generators
git mv lib/annotations/route.dart lib/src/annotations/route.dart
git mv lib/deeplink/deep_link_matcher.dart lib/src/deeplink/deep_link_matcher.dart
git mv lib/handlers/deep_link_handler.dart lib/src/handlers/deep_link_handler.dart
git mv lib/models/route_policy.dart lib/src/models/route_policy.dart
git mv lib/models/route_info.dart lib/src/models/route_info.dart
git mv lib/models/route_args.dart lib/src/models/route_args.dart
git mv lib/router_config.dart lib/src/router_config.dart
git mv lib/generators/generate_route_info_helper.dart lib/src/generators/generate_route_info_helper.dart
git rm lib/models/models.dart
rmdir lib/annotations lib/deeplink lib/handlers lib/models lib/generators 2>/dev/null || true
```

- [ ] **Step 2: Rewrite internal imports to `src` paths**

Update every moved file so its `package:router_builder/...` imports point at the new `src/` paths. The mappings:
- `package:router_builder/models/route_args.dart` -> `package:router_builder/src/models/route_args.dart`
- `package:router_builder/models/route_info.dart` -> `package:router_builder/src/models/route_info.dart`
- `package:router_builder/models/route_policy.dart` -> `package:router_builder/src/models/route_policy.dart`
- `package:router_builder/models/models.dart` -> `package:router_builder/router_builder.dart` (in `deep_link_matcher.dart`)
- `package:router_builder/router_config.dart` -> `package:router_builder/src/router_config.dart`
- `package:router_builder/handlers/deep_link_handler.dart` -> `package:router_builder/src/handlers/deep_link_handler.dart`

Specific edits:
- `lib/src/models/route_info.dart` line 5: `import 'package:router_builder/src/handlers/deep_link_handler.dart';`
- `lib/src/models/route_info.dart` line 6: `import 'package:router_builder/src/models/route_args.dart';` (this becomes a direct policy import in Phase 2; leave args import for now since `RoutePolicy` is still re-exported there).
- `lib/src/models/route_args.dart` lines 2-4: point to `src/models/route_info.dart`, `src/models/route_policy.dart`, `src/router_config.dart`.
- `lib/src/router_config.dart` line 1: `import 'package:router_builder/src/models/route_policy.dart';`
- `lib/src/deeplink/deep_link_matcher.dart` line 2: `import 'package:router_builder/router_builder.dart';`
- `lib/src/handlers/deep_link_handler.dart` line 2: `import 'package:router_builder/src/models/route_info.dart';`

- [ ] **Step 3: Rewrite the public barrel**

`lib/router_builder.dart`:

```dart
/// Public entry point for router_builder: annotations, models, config, the
/// deep-link layer, and handlers. Import this library to define routes and use
/// the generated helper. The code generator lives in `builder.dart`.
library;

export 'src/annotations/route.dart';
export 'src/deeplink/deep_link_matcher.dart';
export 'src/handlers/deep_link_handler.dart';
export 'src/models/duplicate_route_behavior.dart';
export 'src/models/route_args.dart';
export 'src/models/route_info.dart';
export 'src/models/route_policy.dart';
export 'src/router_config.dart';
```

Note: `duplicate_route_behavior.dart` does not exist until Phase 2 Task 2.1. Add that export line in Task 2.1, not here. For Task 1.1, keep the export list to the seven files that exist after the move (no `duplicate_route_behavior.dart`).

- [ ] **Step 4: Add the build entrypoint**

`lib/builder.dart`:

```dart
/// Build entrypoint for router_builder's code generator.
///
/// Referenced by `build.yaml`. Kept separate from the runtime barrel so the
/// generator's heavy dependencies (analyzer, build, dart_style) never reach
/// consumer apps.
library;

export 'src/generators/generate_route_info_helper.dart'
    show generateRouteInfoHelperBuilder;
```

- [ ] **Step 5: Point build.yaml at builder.dart**

`build.yaml` (keep `build_extensions` output name as-is for now; the rename to `routes.g.dart` happens in Phase 6):

```yaml
builders:
  generate_route_info_helper:
    import: "package:router_builder/builder.dart"
    builder_factories: [ "generateRouteInfoHelperBuilder" ]
    build_extensions: { r'$package$': [ "lib/route_info_helper.dart" ] }
    auto_apply: dependents
    build_to: source
```

- [ ] **Step 6: Fix the generator's emitted import strings**

In `lib/src/generators/generate_route_info_helper.dart` `_writeImports` (currently lines 390-410), drop the deep deep-link import from the emitted set (it is re-exported by the barrel). Replace the seeded set so generated files only import the barrel + dhu:

```dart
final importUris = fields.map((f) => f.getString('importUri')).toSet()
  ..addAll([
    'package:dart_helper_utils/dart_helper_utils.dart',
    'package:router_builder/router_builder.dart',
  ]);
```

(The generator's own source imports of `analyzer`/`build`/`dart_style`/`dart_helper_utils`/`glob` are unchanged.)

- [ ] **Step 7: Analyze and test**

Run: `flutter analyze && flutter test`
Expected: analyzer 0 errors (warnings about deprecated-member-use within the package are acceptable at this stage); smoke test PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: adopt lib/src layout with single barrel and builder.dart"
```

---

## Phase 2 - Models and config (D1, D2, D3, D4, D5, D6, D16, D17)

### Task 2.1: Split `DuplicateRouteBehavior` into its own file (O2)

**Files:**
- Create: `lib/src/models/duplicate_route_behavior.dart`
- Modify: `lib/src/models/route_policy.dart` (remove the enum + extension, import the new file)
- Modify: `lib/router_builder.dart` (add the export)
- Test: `test/models/duplicate_route_behavior_test.dart`

- [ ] **Step 1: Write the failing test**

`test/models/duplicate_route_behavior_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  group('DuplicateRouteBehavior', () {
    test('predicates reflect the value', () {
      expect(DuplicateRouteBehavior.duplicate.isDuplicate, isTrue);
      expect(DuplicateRouteBehavior.refresh.isRefresh, isTrue);
      expect(DuplicateRouteBehavior.doNothing.isDoNothing, isTrue);
    });

    test('nullable extension defaults to false', () {
      const DuplicateRouteBehavior? value = null;
      expect(value.isDuplicate, isFalse);
      expect(value.isRefresh, isFalse);
      expect(value.isDoNothing, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run it (still passes today via barrel re-export, confirm green)**

Run: `flutter test test/models/duplicate_route_behavior_test.dart`
Expected: PASS (the enum is currently in `route_policy.dart`, still exported). This test pins behavior before the move.

- [ ] **Step 3: Create the dedicated file**

`lib/src/models/duplicate_route_behavior.dart` (move the enum + extension verbatim from `route_policy.dart` lines 3-34, keeping their doc comments):

```dart
/// Defines behavior when navigating to a route already in the stack.
enum DuplicateRouteBehavior {
  /// Push a new instance of the route onto the stack.
  duplicate,

  /// Replace the current route with updated parameters instead of pushing a new instance.
  refresh,

  /// Cancel the navigation entirely.
  doNothing;

  /// Returns `true` when this behavior pushes a new instance.
  bool get isDuplicate => this == duplicate;

  /// Returns `true` when this behavior replaces the existing route.
  bool get isRefresh => this == refresh;

  /// Returns `true` when this behavior cancels navigation.
  bool get isDoNothing => this == doNothing;
}

/// Convenient boolean checks for nullable [DuplicateRouteBehavior] instances.
extension DuplicateRouteBehaviorEx on DuplicateRouteBehavior? {
  /// Returns `true` when the optional behavior duplicates the route.
  bool get isDuplicate => this?.isDuplicate ?? false;

  /// Returns `true` when the optional behavior refreshes the route.
  bool get isRefresh => this?.isRefresh ?? false;

  /// Returns `true` when the optional behavior cancels navigation.
  bool get isDoNothing => this?.isDoNothing ?? false;
}
```

- [ ] **Step 4: Remove enum from route_policy and import the new file**

In `lib/src/models/route_policy.dart`, delete lines 3-34 (the enum + extension) and add at the top:

```dart
import 'package:router_builder/src/models/duplicate_route_behavior.dart';
```

- [ ] **Step 5: Export from the barrel**

In `lib/router_builder.dart` add (alphabetical, before `route_args.dart`):

```dart
export 'src/models/duplicate_route_behavior.dart';
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/models/duplicate_route_behavior_test.dart && flutter analyze`
Expected: PASS; 0 analyzer errors.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: split DuplicateRouteBehavior into its own file"
```

---

### Task 2.2: `RoutePolicy` v3 - nine fields, merge, copyWith, toMap, report, presets (D1, D17)

**Files:**
- Modify: `lib/src/models/route_policy.dart` (full rewrite of the class body)
- Test: `test/models/route_policy_test.dart`

- [ ] **Step 1: Write the failing tests**

`test/models/route_policy_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  group('RoutePolicy.merge', () {
    test('this wins per field; lower fills gaps', () {
      const upper = RoutePolicy(mustBeAuthorized: false, pushGlobally: true);
      const lower = RoutePolicy(mustBeAuthorized: true, isPopupRoute: true);
      final merged = upper.merge(lower);
      expect(merged.mustBeAuthorized, isFalse); // upper wins
      expect(merged.pushGlobally, isTrue); // only upper set it
      expect(merged.isPopupRoute, isTrue); // filled from lower
      expect(merged.visibleNavBar, isNull); // neither set it
    });

    test('merge(null) returns this', () {
      const p = RoutePolicy(pushGlobally: true);
      expect(p.merge(null), equals(p));
    });
  });

  group('RoutePolicy.copyWith', () {
    test('overrides only provided fields', () {
      const p = RoutePolicy(mustBeAuthorized: true, visibleNavBar: true);
      final c = p.copyWith(visibleNavBar: false);
      expect(c.mustBeAuthorized, isTrue);
      expect(c.visibleNavBar, isFalse);
    });
  });

  group('RoutePolicy presets', () {
    test('expose common shapes', () {
      expect(RoutePolicy.global.pushGlobally, isTrue);
      expect(RoutePolicy.public.mustBeAuthorized, isFalse);
      expect(RoutePolicy.popup.isPopupRoute, isTrue);
    });
  });

  group('RoutePolicy equality', () {
    test('value equality across all nine fields', () {
      expect(
        const RoutePolicy(deepLinkPushGlobally: false),
        equals(const RoutePolicy(deepLinkPushGlobally: false)),
      );
      expect(
        const RoutePolicy(deepLinkPushGlobally: false),
        isNot(equals(const RoutePolicy(deepLinkPushGlobally: true))),
      );
    });
  });

  group('RoutePolicy.report', () {
    test('is JSON encodable and serializes enums by name', () {
      const p = RoutePolicy(
        mustBeAuthorized: false,
        duplicateBehavior: DuplicateRouteBehavior.refresh,
      );
      final map = p.report();
      expect(() => jsonEncode(map), returnsNormally);
      expect(map['duplicateBehavior'], 'refresh');
      expect(map['mustBeAuthorized'], isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/models/route_policy_test.dart`
Expected: FAIL (no `merge`/`copyWith`/`report`/presets/new fields yet).

- [ ] **Step 3: Rewrite `route_policy.dart`**

`lib/src/models/route_policy.dart`:

```dart
import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';

/// A comprehensive, cascading policy for route behavior.
///
/// Every field is nullable; `null` means "not set at this level, defer down the
/// chain" (`args.policy` -> `route.policy` -> [RouterBuilderConfig.defaults]).
/// Use [merge] as the single resolution primitive.
class RoutePolicy extends Equatable {
  /// Creates a route policy. All fields are optional and default to `null`.
  const RoutePolicy({
    this.mustBeAuthorized,
    this.duplicateBehavior,
    this.pushGlobally,
    this.isPopupRoute,
    this.visibleNavBar,
    this.isTopLevelOnly,
    this.shouldReplaceAll,
    this.deepLinkAllowed,
    this.deepLinkPushGlobally,
  });

  /// Whether authentication is required.
  final bool? mustBeAuthorized;

  /// How to handle navigating to a route already in the stack.
  final DuplicateRouteBehavior? duplicateBehavior;

  /// Whether to push on the root navigator.
  final bool? pushGlobally;

  /// Whether the route is presented as a dialog/sheet/popup.
  final bool? isPopupRoute;

  /// Whether the primary navigation UI stays visible.
  final bool? visibleNavBar;

  /// Whether the route stays at the top level of its navigator.
  final bool? isTopLevelOnly;

  /// Whether navigation replaces the entire stack.
  final bool? shouldReplaceAll;

  /// Whether the route is reachable via deep links.
  final bool? deepLinkAllowed;

  /// Whether a deep link to this route pushes on the root navigator.
  final bool? deepLinkPushGlobally;

  /// Preset: push on the root navigator.
  static const RoutePolicy global = RoutePolicy(pushGlobally: true);

  /// Preset: no authentication required.
  static const RoutePolicy public = RoutePolicy(mustBeAuthorized: false);

  /// Preset: presented as a popup.
  static const RoutePolicy popup = RoutePolicy(isPopupRoute: true);

  /// Returns a policy where `this` wins per field and [lower] fills the gaps.
  RoutePolicy merge(RoutePolicy? lower) {
    if (lower == null) return this;
    return RoutePolicy(
      mustBeAuthorized: mustBeAuthorized ?? lower.mustBeAuthorized,
      duplicateBehavior: duplicateBehavior ?? lower.duplicateBehavior,
      pushGlobally: pushGlobally ?? lower.pushGlobally,
      isPopupRoute: isPopupRoute ?? lower.isPopupRoute,
      visibleNavBar: visibleNavBar ?? lower.visibleNavBar,
      isTopLevelOnly: isTopLevelOnly ?? lower.isTopLevelOnly,
      shouldReplaceAll: shouldReplaceAll ?? lower.shouldReplaceAll,
      deepLinkAllowed: deepLinkAllowed ?? lower.deepLinkAllowed,
      deepLinkPushGlobally: deepLinkPushGlobally ?? lower.deepLinkPushGlobally,
    );
  }

  /// Returns a copy with the provided fields overridden.
  ///
  /// Note: a `null` argument leaves the existing value unchanged (copyWith
  /// cannot reset a field back to `null`).
  RoutePolicy copyWith({
    bool? mustBeAuthorized,
    DuplicateRouteBehavior? duplicateBehavior,
    bool? pushGlobally,
    bool? isPopupRoute,
    bool? visibleNavBar,
    bool? isTopLevelOnly,
    bool? shouldReplaceAll,
    bool? deepLinkAllowed,
    bool? deepLinkPushGlobally,
  }) {
    return RoutePolicy(
      mustBeAuthorized: mustBeAuthorized ?? this.mustBeAuthorized,
      duplicateBehavior: duplicateBehavior ?? this.duplicateBehavior,
      pushGlobally: pushGlobally ?? this.pushGlobally,
      isPopupRoute: isPopupRoute ?? this.isPopupRoute,
      visibleNavBar: visibleNavBar ?? this.visibleNavBar,
      isTopLevelOnly: isTopLevelOnly ?? this.isTopLevelOnly,
      shouldReplaceAll: shouldReplaceAll ?? this.shouldReplaceAll,
      deepLinkAllowed: deepLinkAllowed ?? this.deepLinkAllowed,
      deepLinkPushGlobally: deepLinkPushGlobally ?? this.deepLinkPushGlobally,
    );
  }

  /// Raw field map (values not yet normalized; enums stay as enums).
  Map<String, dynamic> toMap() => {
    'mustBeAuthorized': mustBeAuthorized,
    'duplicateBehavior': duplicateBehavior,
    'pushGlobally': pushGlobally,
    'isPopupRoute': isPopupRoute,
    'visibleNavBar': visibleNavBar,
    'isTopLevelOnly': isTopLevelOnly,
    'shouldReplaceAll': shouldReplaceAll,
    'deepLinkAllowed': deepLinkAllowed,
    'deepLinkPushGlobally': deepLinkPushGlobally,
  };

  /// A JSON-safe diagnostic snapshot (enums become their `.name`).
  Map<String, dynamic> report({
    JsonOptions options = const JsonOptions(),
    Object? Function(dynamic)? toEncodable,
  }) => toMap().toJsonMap(options: options, toEncodable: toEncodable);

  @override
  List<Object?> get props => [
    mustBeAuthorized,
    duplicateBehavior,
    pushGlobally,
    isPopupRoute,
    visibleNavBar,
    isTopLevelOnly,
    shouldReplaceAll,
    deepLinkAllowed,
    deepLinkPushGlobally,
  ];
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/models/route_policy_test.dart`
Expected: PASS. (`route_info.dart`/`route_args.dart`/`router_config.dart` still construct `RoutePolicy` with the four original fields - all still optional, so they keep compiling.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: RoutePolicy v3 (9 fields, merge, copyWith, report, presets)"
```

---

### Task 2.3: `RouterBuilderConfig` v3 - complete encapsulated defaults (D3)

**Files:**
- Modify: `lib/src/router_config.dart` (full rewrite)
- Test: `test/models/router_config_test.dart`

- [ ] **Step 1: Write the failing tests**

`test/models/router_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  test('built-in defaults are complete (all nine fields non-null)', () {
    final d = RouterBuilderConfig.defaults;
    expect(d.mustBeAuthorized, isTrue);
    expect(d.duplicateBehavior, DuplicateRouteBehavior.duplicate);
    expect(d.pushGlobally, isFalse);
    expect(d.isPopupRoute, isFalse);
    expect(d.visibleNavBar, isTrue);
    expect(d.isTopLevelOnly, isFalse);
    expect(d.shouldReplaceAll, isFalse);
    expect(d.deepLinkAllowed, isTrue);
    expect(d.deepLinkPushGlobally, isTrue);
  });

  test('setDefaults overrides yet stays complete', () {
    RouterBuilderConfig.setDefaults(
      const RoutePolicy(mustBeAuthorized: false, deepLinkAllowed: false),
    );
    final d = RouterBuilderConfig.defaults;
    expect(d.mustBeAuthorized, isFalse); // overridden
    expect(d.deepLinkAllowed, isFalse); // overridden
    expect(d.visibleNavBar, isTrue); // still complete from built-ins
    expect(d.duplicateBehavior, DuplicateRouteBehavior.duplicate);
  });

  test('reset restores built-ins and clears configured flag', () {
    RouterBuilderConfig.setDefaults(const RoutePolicy(mustBeAuthorized: false));
    RouterBuilderConfig.markConfigured();
    RouterBuilderConfig.reset();
    expect(RouterBuilderConfig.defaults.mustBeAuthorized, isTrue);
    expect(RouterBuilderConfig.isConfigured, isFalse);
  });

  test('markConfigured flips isConfigured', () {
    expect(RouterBuilderConfig.isConfigured, isFalse);
    RouterBuilderConfig.markConfigured();
    expect(RouterBuilderConfig.isConfigured, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/models/router_config_test.dart`
Expected: FAIL (`reset`/`isConfigured`/`markConfigured`/`setDefaults(RoutePolicy)` do not exist; defaults incomplete).

- [ ] **Step 3: Rewrite `router_config.dart`**

`lib/src/router_config.dart`:

```dart
import 'package:router_builder/src/models/duplicate_route_behavior.dart';
import 'package:router_builder/src/models/route_policy.dart';

/// Global configuration for router_builder.
///
/// Holds one complete [RoutePolicy] so resolution always terminates with
/// non-null values. Override it wholesale in `main()` (directly or via the
/// generated `installDefaults()`).
class RouterBuilderConfig {
  RouterBuilderConfig._();

  static const RoutePolicy _builtInDefaults = RoutePolicy(
    mustBeAuthorized: true,
    duplicateBehavior: DuplicateRouteBehavior.duplicate,
    pushGlobally: false,
    isPopupRoute: false,
    visibleNavBar: true,
    isTopLevelOnly: false,
    shouldReplaceAll: false,
    deepLinkAllowed: true,
    deepLinkPushGlobally: true,
  );

  static RoutePolicy _defaults = _builtInDefaults;

  static bool _isConfigured = false;

  /// The complete global default policy (always fully non-null).
  static RoutePolicy get defaults => _defaults;

  /// Overrides the global defaults; merges over the built-ins so the result
  /// stays complete.
  static void setDefaults(RoutePolicy policy) =>
      _defaults = policy.merge(_defaults);

  /// Restores the built-in defaults and clears [isConfigured] (use in tests).
  static void reset() {
    _defaults = _builtInDefaults;
    _isConfigured = false;
  }

  /// Whether [markConfigured] has run (e.g. via the generated installDefaults()).
  static bool get isConfigured => _isConfigured;

  /// Marks defaults as installed; enables optional debug fail-fast asserts.
  static void markConfigured() => _isConfigured = true;
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/models/router_config_test.dart`
Expected: PASS.

Note: `RouteArgs`/`RouteInfo` read `RouterBuilderConfig.defaults` (a getter now) - still compiles. No internal caller uses the old `setDefaults({named})`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: RouterBuilderConfig v3 (complete encapsulated defaults, reset, isConfigured)"
```

---

### Task 2.4: Resolution core - `RouteInfo` + `RouteArgs` v3 (D4, D5, D6, D16, D17)

`RouteInfo` and `RouteArgs` are the coupled resolution pair, rewritten together so the package compiles in one commit. This removes all deprecated flat params/getters, removes `isIdSlug`, deletes `RouteArgs._`, adds `constrain`/`resolvedPolicy`/`effectivePolicy`, same-named non-null resolved getters, fixed `props`, direct policy import, and JSON-safe `report()`. The deep-link matcher's `_buildArgs` and `RouteArgs.fromUri` are updated to the new API in the same commit.

**Refinement over the spec's literal code:** `constrain` is applied to the user-supplied policy *before* merging global defaults (not after). The resolved values are identical (forced fields end up `false` either way, and defaults fill the rest), but the debug `assert` then fires only on genuine user conflicts - not when a default supplies a value the constraint must override (e.g. a branch's `deepLinkPushGlobally`, whose default is `true`).

**Files:**
- Modify: `lib/src/models/route_info.dart` (full rewrite)
- Modify: `lib/src/models/route_args.dart` (full rewrite)
- Modify: `lib/src/deeplink/deep_link_matcher.dart` (`_buildArgs` only)
- Test: `test/models/route_info_test.dart`, `test/models/route_args_test.dart`, `test/resolution_matrix_test.dart`

- [ ] **Step 1: Write the failing tests**

`test/models/route_info_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  group('RouteInfo resolved getters', () {
    test('fall back to global defaults when policy is null', () {
      const r = RouteInfo('home', child: SizedBox());
      expect(r.mustBeAuthorized, isTrue);
      expect(r.pushGlobally, isFalse);
      expect(r.duplicateBehavior, DuplicateRouteBehavior.duplicate);
      expect(r.deepLinkAllowed, isTrue);
      expect(r.deepLinkPushGlobally, isTrue);
      expect(r.visibleNavBar, isTrue);
    });

    test('route.policy overrides defaults', () {
      const r = RouteInfo(
        'admin',
        child: SizedBox(),
        policy: RoutePolicy(pushGlobally: true, mustBeAuthorized: false),
      );
      expect(r.pushGlobally, isTrue);
      expect(r.mustBeAuthorized, isFalse);
    });

    test('installed global defaults reflect in resolved getters', () {
      RouterBuilderConfig.setDefaults(const RoutePolicy(mustBeAuthorized: false));
      const r = RouteInfo('home', child: SizedBox());
      expect(r.mustBeAuthorized, isFalse);
    });
  });

  group('RouteInfo.constrain', () {
    test('branch forces structural fields false (no conflict needed)', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
      );
      final resolved = branch.resolvedPolicy;
      expect(resolved.pushGlobally, isFalse);
      expect(resolved.isPopupRoute, isFalse);
      // default deepLinkPushGlobally is true; the branch constraint forces false
      expect(resolved.deepLinkPushGlobally, isFalse);
    });

    test('branch policy conflicting with a forced field asserts in debug', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
        policy: RoutePolicy(pushGlobally: true),
      );
      expect(() => branch.resolvedPolicy, throwsA(isA<AssertionError>()));
    });

    test('redirect forces isPopupRoute/visibleNavBar/shouldReplaceAll false', () {
      const redirect = RouteInfo.redirect('gate', redirect: _noRedirect);
      final resolved = redirect.resolvedPolicy;
      expect(resolved.isPopupRoute, isFalse);
      expect(resolved.visibleNavBar, isFalse);
      expect(resolved.shouldReplaceAll, isFalse);
    });
  });

  group('RouteInfo equality', () {
    test('props include branchParentType and deepLinkNames', () {
      const a = RouteInfo('e', child: SizedBox(), deepLinkNames: ['x']);
      const b = RouteInfo('e', child: SizedBox(), deepLinkNames: ['y']);
      expect(a, isNot(equals(b)));
    });
  });

  group('RouteInfo.report', () {
    test('is JSON encodable with presence flags and resolved policy', () {
      const r = RouteInfo('home', builder: _build, deepLinkNames: ['h']);
      final map = r.report();
      expect(() => jsonEncode(map), returnsNormally);
      expect(map['hasBuilder'], isTrue);
      expect(map['hasChild'], isFalse);
      expect((map['resolvedPolicy'] as Map)['mustBeAuthorized'], isTrue);
    });
  });
}

enum _Shell { market }

String? _noRedirect(BuildContext context, RouteArgs? args) => null;

Widget _build(BuildContext context, RouteArgs? args) => const SizedBox();
```

`test/models/route_args_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  group('RouteArgs.effectivePolicy precedence', () {
    test('args policy wins over route policy wins over defaults', () {
      const route = RouteInfo(
        'p',
        child: SizedBox(),
        policy: RoutePolicy(mustBeAuthorized: false, pushGlobally: true),
      );
      const args = RouteArgs(route, policy: RoutePolicy(pushGlobally: false));
      expect(args.effectivePushGlobally, isFalse); // args wins
      expect(args.effectiveMustBeAuthorized, isFalse); // from route
      expect(args.effectiveVisibleNavBar, isTrue); // from defaults
    });

    test('branch args setting a forced field assert in debug', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
      );
      const args = RouteArgs(branch, policy: RoutePolicy(pushGlobally: true));
      expect(() => args.effectivePolicy, throwsA(isA<AssertionError>()));
    });

    test('branch deepLinkPushGlobally is forced false without conflict', () {
      const branch = RouteInfo.branch(
        'tab',
        branchIndex: 0,
        branchKey: '_k',
        branchParentType: _Shell.market,
        child: SizedBox(),
      );
      const args = RouteArgs(branch);
      expect(args.effectiveDeepLinkPushGlobally, isFalse);
    });
  });

  group('RouteArgs copyWith / cleared', () {
    test('copyWith overrides policy and keeps route', () {
      const route = RouteInfo('p', child: SizedBox());
      const args = RouteArgs(route, id: '1');
      final c = args.copyWith(policy: const RoutePolicy(pushGlobally: true));
      expect(c.id, '1');
      expect(c.effectivePushGlobally, isTrue);
    });

    test('cleared drops resumeTo/comingFrom but keeps nav context', () {
      const route = RouteInfo('p', child: SizedBox());
      const prev = RouteArgs(route);
      final args = RouteArgs(route, id: '1', resumeTo: prev, comingFrom: prev);
      final cleared = args.cleared();
      expect(cleared.id, '1');
      expect(cleared.resumeTo, isNull);
      expect(cleared.comingFrom, isNull);
    });
  });

  group('RouteArgs subclassing', () {
    test('forwards policy via super-params and resolves', () {
      const route = RouteInfo('dlg', child: SizedBox());
      final args = _DialogArgs(route, policy: const RoutePolicy.popup());
      expect(args.effectiveIsPopupRoute, isTrue);
    });
  });

  group('RouteArgs.report', () {
    test('is JSON encodable with effective policy and shallow route summary', () {
      const route = RouteInfo('p', child: SizedBox());
      final args = RouteArgs(route, id: '7', object: _NotEncodable());
      final map = args.report(toEncodable: (v) => v is _NotEncodable ? 'X' : v);
      expect(() => jsonEncode(map), returnsNormally);
      expect((map['route'] as Map)['name'], 'p');
      expect(map['object'], 'X');
      expect((map['effectivePolicy'] as Map)['mustBeAuthorized'], isTrue);
    });
  });

  test('RouteArgsX.requiresAuth', () {
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(route);
    expect(args.requiresAuth, isTrue);
    const RouteArgs? none = null;
    expect(none.requiresAuth, isFalse);
  });
}

enum _Shell { market }

class _DialogArgs extends RouteArgs {
  const _DialogArgs(super.route, {super.policy, super.id});
}

class _NotEncodable {}
```

`test/resolution_matrix_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

/// Golden precedence matrix: for each field, args.policy beats route.policy
/// beats installed defaults. Each row sets exactly one layer and asserts the
/// effective value.
void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  test('args layer wins for every boolean field', () {
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(
      route,
      policy: RoutePolicy(
        mustBeAuthorized: false,
        pushGlobally: true,
        isPopupRoute: true,
        visibleNavBar: false,
        isTopLevelOnly: true,
        shouldReplaceAll: true,
        deepLinkAllowed: false,
        deepLinkPushGlobally: false,
      ),
    );
    expect(args.effectiveMustBeAuthorized, isFalse);
    expect(args.effectivePushGlobally, isTrue);
    expect(args.effectiveIsPopupRoute, isTrue);
    expect(args.effectiveVisibleNavBar, isFalse);
    expect(args.effectiveIsTopLevelOnly, isTrue);
    expect(args.effectiveShouldReplaceAll, isTrue);
    expect(args.effectiveDeepLinkAllowed, isFalse);
    expect(args.effectiveDeepLinkPushGlobally, isFalse);
  });

  test('route layer wins when args is silent', () {
    const route = RouteInfo(
      'p',
      child: SizedBox(),
      policy: RoutePolicy(isTopLevelOnly: true, mustBeAuthorized: false),
    );
    const args = RouteArgs(route);
    expect(args.effectiveIsTopLevelOnly, isTrue);
    expect(args.effectiveMustBeAuthorized, isFalse);
  });

  test('installed defaults win when args and route are silent', () {
    RouterBuilderConfig.setDefaults(
      const RoutePolicy(duplicateBehavior: DuplicateRouteBehavior.refresh),
    );
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(route);
    expect(args.effectiveDuplicateBehavior, DuplicateRouteBehavior.refresh);
  });

  test('built-in defaults win when nothing is configured', () {
    const route = RouteInfo('p', child: SizedBox());
    const args = RouteArgs(route);
    expect(args.effectiveDuplicateBehavior, DuplicateRouteBehavior.duplicate);
    expect(args.effectiveMustBeAuthorized, isTrue);
    expect(args.effectiveVisibleNavBar, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/models/route_info_test.dart test/models/route_args_test.dart test/resolution_matrix_test.dart`
Expected: FAIL to compile (`effectiveX` shapes changed, `resolvedPolicy`/`constrain` missing, `RoutePolicy.popup` const usage, etc.).

- [ ] **Step 3: Rewrite `route_info.dart`**

`lib/src/models/route_info.dart`:

```dart
import 'dart:async';

import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:router_builder/src/handlers/deep_link_handler.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';
import 'package:router_builder/src/models/route_args.dart';
import 'package:router_builder/src/models/route_policy.dart';
import 'package:router_builder/src/router_config.dart';

/// Builds a localized title for a route.
typedef ScreenTitleBuilder =
    String Function(BuildContext context, RouteArgs? args);

/// Builds the widget for a route.
typedef ScreenWidgetBuilder =
    Widget Function(BuildContext context, RouteArgs? args);

/// Builds a custom [Page] for a route, enabling tailored transitions.
typedef ScreenPageBuilder =
    Page<dynamic> Function(BuildContext context, RouteArgs? args);

/// The signature of the redirect callback.
typedef RouterRedirect =
    FutureOr<String?> Function(BuildContext context, RouteArgs? args);

/// Declarative configuration for a navigation route.
///
/// Behavioral settings live in [policy]; read them back through the same-named
/// resolved getters (e.g. [pushGlobally], [mustBeAuthorized]), which fold
/// `route.policy` over [RouterBuilderConfig.defaults] and apply structural
/// constraints. Annotate static or top-level `RouteInfo` values with `@RT` to
/// include them in code generation.
class RouteInfo extends Equatable {
  /// Creates a standard navigation route.
  ///
  /// Exactly one of [builder], [child], or [pageBuilder] must be provided.
  const RouteInfo(
    this.name, {
    this.title,
    this.builder,
    this.child,
    this.pageBuilder,
    this.redirect,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.policy,
    String? path,
  }) : _path = path,
       isBranch = false,
       branchIndex = null,
       branchKey = null,
       branchParentType = null,
       forRedirectionOnly = false,
       assert(
         (builder != null && child == null && pageBuilder == null) ||
             (builder == null && child != null && pageBuilder == null) ||
             (builder == null && child == null && pageBuilder != null),
         'Exactly one of builder, child, or pageBuilder must be provided.',
       );

  /// Creates a route that only performs redirection (no UI of its own).
  const RouteInfo.redirect(
    this.name, {
    required this.redirect,
    this.title,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.policy,
    String? path,
  }) : _path = path,
       builder = null,
       child = null,
       pageBuilder = null,
       isBranch = false,
       branchIndex = null,
       branchKey = null,
       branchParentType = null,
       forRedirectionOnly = true;

  /// Creates a route that belongs to a navigation shell (e.g. a tab).
  ///
  /// Branches are grouped by [branchParentType] and ordered by [branchIndex];
  /// [branchKey] names the branch's navigator key.
  const RouteInfo.branch(
    this.name, {
    required this.branchIndex,
    required this.branchKey,
    required this.branchParentType,
    this.title,
    this.child,
    this.builder,
    this.pageBuilder,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.policy,
    String? path,
  }) : _path = path,
       isBranch = true,
       redirect = null,
       forRedirectionOnly = false,
       assert(
         (builder != null && child == null && pageBuilder == null) ||
             (builder == null && child != null && pageBuilder == null) ||
             (builder == null && child == null && pageBuilder != null),
         'Exactly one of builder, child, or pageBuilder must be provided.',
       );

  /// Unique identifier for this route.
  final String name;

  /// Whether this route is used solely for redirection.
  final bool forRedirectionOnly;

  /// Whether this route belongs to a navigation shell.
  final bool isBranch;

  /// Position of this branch within its shell (branch routes only).
  final int? branchIndex;

  /// Navigator key identifier for branch routes.
  final String? branchKey;

  /// Enum discriminator used to group branch routes.
  final Enum? branchParentType;

  /// Localized title provider for this route.
  final ScreenTitleBuilder? title;

  /// Builds the widget for this route when navigation occurs.
  final ScreenWidgetBuilder? builder;

  /// Static widget instance for routes that do not need a builder.
  final Widget? child;

  /// Builds a custom [Page] for this route.
  final ScreenPageBuilder? pageBuilder;

  /// Redirect handler for conditional navigation.
  final RouterRedirect? redirect;

  /// Alternative names for deep-link matching.
  final List<String> deepLinkNames;

  /// Handler for complex deep-link logic beyond navigation.
  final DeepLinkHandler<dynamic>? deepLinkHandler;

  /// Comprehensive behavioral policy for this route.
  final RoutePolicy? policy;

  /// Backing field for [path]; defaults to `/$name` when null.
  final String? _path;

  /// The route's path segment (defaults to `/$name`).
  String get path => _path ?? '/$name';

  /// Applies branch/redirect structural constraints to [policy].
  ///
  /// Branches force `pushGlobally`/`isPopupRoute`/`deepLinkPushGlobally` false;
  /// redirect-only routes force `isPopupRoute`/`visibleNavBar`/`shouldReplaceAll`
  /// false. In debug builds, an assert fires if [policy] tries to set a forced
  /// field to a conflicting value.
  RoutePolicy constrain(RoutePolicy policy) {
    if (isBranch) {
      assert(
        policy.pushGlobally != true &&
            policy.isPopupRoute != true &&
            policy.deepLinkPushGlobally != true,
        'Branch route "$name": pushGlobally/isPopupRoute/deepLinkPushGlobally '
        'are forced false and cannot be set via policy.',
      );
      return policy.copyWith(
        pushGlobally: false,
        isPopupRoute: false,
        deepLinkPushGlobally: false,
      );
    }
    if (forRedirectionOnly) {
      assert(
        policy.isPopupRoute != true &&
            policy.visibleNavBar != true &&
            policy.shouldReplaceAll != true,
        'Redirect route "$name": isPopupRoute/visibleNavBar/shouldReplaceAll '
        'are forced false and cannot be set via policy.',
      );
      return policy.copyWith(
        isPopupRoute: false,
        visibleNavBar: false,
        shouldReplaceAll: false,
      );
    }
    return policy;
  }

  /// This route's policy folded over global defaults, then constrained.
  ///
  /// All nine fields are non-null. Does not include per-call (`args`) overrides.
  RoutePolicy get resolvedPolicy => constrain(
    policy ?? const RoutePolicy(),
  ).merge(RouterBuilderConfig.defaults);

  /// Whether authentication is required (resolved).
  bool get mustBeAuthorized => resolvedPolicy.mustBeAuthorized!;

  /// How duplicates are handled (resolved).
  DuplicateRouteBehavior get duplicateBehavior =>
      resolvedPolicy.duplicateBehavior!;

  /// Whether this route pushes on the root navigator (resolved).
  bool get pushGlobally => resolvedPolicy.pushGlobally!;

  /// Whether this route is a popup (resolved).
  bool get isPopupRoute => resolvedPolicy.isPopupRoute!;

  /// Whether the primary nav UI stays visible (resolved).
  bool get visibleNavBar => resolvedPolicy.visibleNavBar!;

  /// Whether this route stays top-level in its navigator (resolved).
  bool get isTopLevelOnly => resolvedPolicy.isTopLevelOnly!;

  /// Whether navigation replaces the whole stack (resolved).
  bool get shouldReplaceAll => resolvedPolicy.shouldReplaceAll!;

  /// Whether this route is reachable via deep links (resolved).
  bool get deepLinkAllowed => resolvedPolicy.deepLinkAllowed!;

  /// Whether a deep link to this route pushes globally (resolved).
  bool get deepLinkPushGlobally => resolvedPolicy.deepLinkPushGlobally!;

  /// Builds a hierarchical name optionally scoped under [parentRoute].
  String generateName({RouteInfo? parentRoute}) =>
      parentRoute != null ? '${parentRoute.name}.$name' : name;

  /// Builds a hierarchical path optionally scoped under [parentRoute].
  String generatePath({RouteInfo? parentRoute}) =>
      parentRoute != null ? name : path;

  /// A rich, JSON-safe diagnostic snapshot (closures become presence flags;
  /// the resolved policy is included).
  Map<String, dynamic> report({
    JsonOptions options = const JsonOptions(),
    Object? Function(dynamic)? toEncodable,
  }) => _rawReport().toJsonMap(options: options, toEncodable: toEncodable);

  Map<String, dynamic> _rawReport() => {
    'name': name,
    'path': path,
    'isBranch': isBranch,
    'forRedirectionOnly': forRedirectionOnly,
    'branchIndex': branchIndex,
    'branchKey': branchKey,
    'branchParentType': branchParentType,
    'deepLinkNames': deepLinkNames,
    'hasTitle': title != null,
    'hasBuilder': builder != null,
    'hasChild': child != null,
    'hasPageBuilder': pageBuilder != null,
    'hasRedirect': redirect != null,
    'hasDeepLinkHandler': deepLinkHandler != null,
    'policy': policy?.toMap(),
    'resolvedPolicy': resolvedPolicy.toMap(),
  };

  @override
  List<Object?> get props => [
    name,
    path,
    isBranch,
    forRedirectionOnly,
    branchIndex,
    branchKey,
    branchParentType,
    deepLinkNames,
    policy,
  ];
}
```

- [ ] **Step 4: Rewrite `route_args.dart`**

`lib/src/models/route_args.dart`:

```dart
import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:router_builder/src/models/duplicate_route_behavior.dart';
import 'package:router_builder/src/models/route_info.dart';
import 'package:router_builder/src/models/route_policy.dart';
import 'package:router_builder/src/router_config.dart';

/// Per-call navigation arguments for a [RouteInfo].
///
/// Carries the target route plus optional id/params/object and a per-call
/// [policy] override. Resolution folds `args.policy` over `route.policy` over
/// [RouterBuilderConfig.defaults], then applies structural constraints; read
/// the result through the `effectiveX` getters. Subclass via super-parameters
/// (e.g. dialog/sheet args) - the constructor shape is an extensibility
/// contract.
class RouteArgs extends Equatable {
  /// Creates navigation arguments for [route].
  const RouteArgs(
    this.route, {
    this.id,
    this.queryParams,
    this.pathParams,
    this.object,
    this.resumeTo,
    this.comingFrom,
    this.isFromDeeplink = false,
    this.policy,
  });

  /// Builds args from a [uri] using [route]'s path template.
  factory RouteArgs.fromUri(RouteInfo route, Uri uri) {
    final template =
        route.path.startsWith('/') ? route.path.substring(1) : route.path;

    Map<String, String> extract(String template) {
      final uriSegments = uri.pathSegments;
      final templateSegments = template
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      final params = <String, String>{};
      final len = uriSegments.length < templateSegments.length
          ? uriSegments.length
          : templateSegments.length;
      for (var i = 0; i < len; i++) {
        final t = templateSegments[i];
        final u = uriSegments[i];
        if (t.startsWith(':') && t.length > 1) {
          params[t.substring(1)] = u;
        }
      }
      return params;
    }

    final pathParams = extract(template);
    final qp = <String, String>{}..addAll(uri.queryParameters);
    return RouteArgs(
      route,
      id:
          pathParams['id'] ??
          (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null),
      pathParams: pathParams.isEmpty ? null : pathParams,
      queryParams: qp.isEmpty ? null : qp,
      isFromDeeplink: true,
    );
  }

  /// The target route to navigate to.
  final RouteInfo route;

  /// Optional id parameter (e.g. from path `/users/:id`).
  final String? id;

  /// Named path parameters extracted from the route's path template.
  final Map<String, String>? pathParams;

  /// Query parameters from the URI.
  final Map<String, String>? queryParams;

  /// Arbitrary payload to pass to the route.
  final Object? object;

  /// Optional resume intent.
  final RouteArgs? resumeTo;

  /// The originating navigation, if any.
  final RouteArgs? comingFrom;

  /// Whether this navigation originated from a deep link.
  final bool isFromDeeplink;

  /// Per-call policy override.
  final RoutePolicy? policy;

  /// The fully resolved, constrained policy for this navigation call.
  ///
  /// Precedence: `args.policy` -> `route.policy` -> defaults; structural
  /// constraints applied last. All nine fields are non-null.
  RoutePolicy get effectivePolicy => route
      .constrain((policy ?? const RoutePolicy()).merge(route.policy))
      .merge(RouterBuilderConfig.defaults);

  /// Resolved authentication requirement.
  bool get effectiveMustBeAuthorized => effectivePolicy.mustBeAuthorized!;

  /// Resolved duplicate behavior.
  DuplicateRouteBehavior get effectiveDuplicateBehavior =>
      effectivePolicy.duplicateBehavior!;

  /// Resolved root-navigator push setting.
  bool get effectivePushGlobally => effectivePolicy.pushGlobally!;

  /// Resolved popup setting.
  bool get effectiveIsPopupRoute => effectivePolicy.isPopupRoute!;

  /// Resolved nav-bar visibility.
  bool get effectiveVisibleNavBar => effectivePolicy.visibleNavBar!;

  /// Resolved top-level-only setting.
  bool get effectiveIsTopLevelOnly => effectivePolicy.isTopLevelOnly!;

  /// Resolved replace-all setting.
  bool get effectiveShouldReplaceAll => effectivePolicy.shouldReplaceAll!;

  /// Resolved deep-link allowance.
  bool get effectiveDeepLinkAllowed => effectivePolicy.deepLinkAllowed!;

  /// Resolved deep-link push-global setting.
  bool get effectiveDeepLinkPushGlobally =>
      effectivePolicy.deepLinkPushGlobally!;

  /// Returns a copy with the provided fields overridden.
  RouteArgs copyWith({
    RouteInfo? route,
    String? id,
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    Object? object,
    RouteArgs? resumeTo,
    RouteArgs? comingFrom,
    bool? isFromDeeplink,
    RoutePolicy? policy,
  }) => RouteArgs(
    route ?? this.route,
    id: id ?? this.id,
    pathParams: pathParams ?? this.pathParams,
    queryParams: queryParams ?? this.queryParams,
    object: object ?? this.object,
    resumeTo: resumeTo ?? this.resumeTo,
    comingFrom: comingFrom ?? this.comingFrom,
    isFromDeeplink: isFromDeeplink ?? this.isFromDeeplink,
    policy: policy ?? this.policy,
  );

  /// Returns a copy with navigation context preserved but flow metadata cleared.
  RouteArgs cleared() => RouteArgs(
    route,
    id: id,
    pathParams: pathParams,
    queryParams: queryParams,
    object: object,
    isFromDeeplink: isFromDeeplink,
    policy: policy,
  );

  /// A rich, JSON-safe diagnostic snapshot (effective policy + shallow route /
  /// resumeTo / comingFrom summaries to avoid cycles).
  Map<String, dynamic> report({
    JsonOptions options = const JsonOptions(),
    Object? Function(dynamic)? toEncodable,
  }) => _rawReport().toJsonMap(options: options, toEncodable: toEncodable);

  Map<String, dynamic> _rawReport() => {
    'route': {'name': route.name, 'path': route.path},
    'id': id,
    'pathParams': pathParams,
    'queryParams': queryParams,
    'object': object,
    'isFromDeeplink': isFromDeeplink,
    'resumeTo': resumeTo == null
        ? null
        : {'name': resumeTo!.route.name, 'id': resumeTo!.id},
    'comingFrom': comingFrom == null
        ? null
        : {'name': comingFrom!.route.name, 'id': comingFrom!.id},
    'effectivePolicy': effectivePolicy.toMap(),
  };

  @override
  List<Object?> get props => [
    route,
    id,
    pathParams,
    queryParams,
    object,
    resumeTo,
    comingFrom,
    isFromDeeplink,
    policy,
  ];
}

/// Convenience helpers for nullable [RouteArgs].
extension RouteArgsX on RouteArgs? {
  /// Whether the underlying route requires authorization.
  bool get requiresAuth => this?.effectiveMustBeAuthorized ?? false;
}
```

- [ ] **Step 5: Update the matcher's `_buildArgs` to the new API**

In `lib/src/deeplink/deep_link_matcher.dart` replace `_buildArgs` (currently lines 105-111):

```dart
  RouteArgs _buildArgs(RouteInfo route, Uri uri, Uri? original) {
    final pushGlobally = route.resolvedPolicy.deepLinkPushGlobally!;
    return RouteArgs.fromUri(route, uri).copyWith(
      policy: RoutePolicy(pushGlobally: pushGlobally),
      object: original ?? uri,
    );
  }
```

(The host-matching security fix and resolved-`deepLinkAllowed` gating are Phase 5; this step only keeps the matcher compiling against the new `RouteArgs`.)

- [ ] **Step 6: Run the model + smoke + matrix tests**

Run: `flutter test test/smoke_test.dart test/models/ test/resolution_matrix_test.dart`
Expected: PASS. Then `flutter analyze` - expect 0 errors. (Resolve any remaining references to removed members - there should be none inside `lib/`.)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: RouteInfo/RouteArgs v3 resolution core (policy-only, resolved getters, report)"
```

---

## Phase 3 - `@RTConfig` annotation (D8, annotation part)

### Task 3.1: Add the `RTConfig` annotation

**Files:**
- Modify: `lib/src/annotations/route.dart`

- [ ] **Step 1: Add `RTConfig` alongside `RT`**

Append to `lib/src/annotations/route.dart`:

```dart
/// Marks a `const RoutePolicy` as the app's global route defaults.
///
/// Exactly one declaration is allowed per package (the generator fails the
/// build on duplicates, or on a non-const / non-`RoutePolicy` target). The
/// generator emits `<RoutesHelper>.installDefaults()`; call it once in `main()`.
///
/// Example:
/// ```dart
/// @RTConfig()
/// const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);
/// ```
class RTConfig {
  /// Creates an [RTConfig] annotation.
  const RTConfig();
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/src/annotations/route.dart`
Expected: 0 errors. (Generator wiring is Task 4.1.)

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add @RTConfig annotation"
```

---

## Phase 4 - Generator (D7, D8 wiring, D11, D12, D13 conflict, D14, D15, D16)

The generator is rewritten as a unit: it reads `BuilderOptions`, discovers `@RT` on class statics AND top-level consts/finals, extracts only statically-true metadata (DartObject-first with AST fallback; enum `branchParentType` stays on the AST path), emits `allRoutes` (every route, including redirect-only) plus the `Routes` constants, branch map, and `deepLinkMap` as data, derives behavior categories as runtime getters, fails the build on deep-link key conflicts and on invalid/duplicate `@RTConfig`, and emits `installDefaults()`.

### Task 4.1: Rewrite the generator

**Files:**
- Modify: `lib/src/generators/generate_route_info_helper.dart` (full replacement)
- Modify: `lib/builder.dart` (also export `RouterBuilderError`)
- Test: `test/generator/_support.dart`, `test/generator/generator_options_test.dart`, `test/generator/generator_discovery_test.dart`, `test/generator/generator_output_test.dart`, `test/generator/generator_conflict_test.dart`, `test/generator/generator_rtconfig_test.dart`

- [ ] **Step 1: Add the shared test support**

`test/generator/_support.dart`:

```dart
import 'package:build/build.dart';
import 'package:router_builder/builder.dart';

/// Prefixes fixture paths with the router_builder package id for testBuilder.
Map<String, Object> assets(Map<String, String> sources) => {
  for (final e in sources.entries) 'router_builder|${e.key}': e.value,
};

/// The generator under test, configured with [options].
Builder generator([Map<String, dynamic> options = const {}]) =>
    generateRouteInfoHelperBuilder(BuilderOptions(options));

/// A minimal fixture: one standard route + one redirect-only route.
const String basicFixture = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());

  @RT()
  static const gate = RouteInfo.redirect('gate', redirect: _to);
}

String? _to(BuildContext c, RouteArgs? a) => null;
''';
```

- [ ] **Step 2: Write the failing generator tests**

`test/generator/generator_options_test.dart`:

```dart
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

void main() {
  test('defaults to Routes/RoutesHelper at lib/routes.g.dart', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': basicFixture}),
      rootPackage: 'router_builder',
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(contains('abstract class Routes'),
              contains('abstract class RoutesHelper')),
        ),
      },
    );
  });

  test('honors custom class names and output path', () async {
    await testBuilder(
      generator({
        'output': 'lib/nav.g.dart',
        'route_class_name': 'AppRoute',
        'helper_class_name': 'NavHelper',
      }),
      assets({'lib/app_routes.dart': basicFixture}),
      rootPackage: 'router_builder',
      outputs: {
        'router_builder|lib/nav.g.dart': decodedMatches(
          allOf(contains('abstract class AppRoute'),
              contains('abstract class NavHelper')),
        ),
      },
    );
  });
}
```

`test/generator/generator_discovery_test.dart`:

```dart
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

const _topLevelFixture = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

@RT()
const settings = RouteInfo('settings', child: SizedBox());

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());
}
''';

void main() {
  test('discovers class statics AND top-level consts', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': _topLevelFixture}),
      rootPackage: 'router_builder',
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(contains('AppRoutes.home'), contains('settings')),
        ),
      },
    );
  });
}
```

`test/generator/generator_output_test.dart`:

```dart
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

void main() {
  test('emits runtime category getters and includes redirect routes', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': basicFixture}),
      rootPackage: 'router_builder',
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(
            contains('static List<RouteInfo> get normalRoutes'),
            contains('static List<RouteInfo> get redirectRoutes'),
            contains('static List<RouteInfo> get authorizedRoutes'),
            contains('static final List<RouteInfo> allRoutes'),
            contains('AppRoutes.gate'), // redirect-only present in allRoutes
            contains('static final Map<String, RouteInfo> deepLinkMap'),
            contains('static void installDefaults()'),
          ),
        ),
      },
    );
  });
}
```

`test/generator/generator_conflict_test.dart`:

```dart
import 'package:build_test/build_test.dart';
import 'package:router_builder/builder.dart';
import 'package:test/test.dart';

import '_support.dart';

const _conflict = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

abstract class AppRoutes {
  @RT()
  static const a = RouteInfo('dup', child: SizedBox());

  @RT()
  static const b = RouteInfo('other', deepLinkNames: ['dup'], child: SizedBox());
}
''';

void main() {
  test('deep-link key conflict fails the build by default', () {
    expect(
      testBuilder(
        generator(),
        assets({'lib/app_routes.dart': _conflict}),
        rootPackage: 'router_builder',
      ),
      throwsA(isA<RouterBuilderError>()),
    );
  });

  test('fail_on_conflict:false keeps the build green', () async {
    await testBuilder(
      generator({'fail_on_conflict': false}),
      assets({'lib/app_routes.dart': _conflict}),
      rootPackage: 'router_builder',
      onLog: (_) {},
      outputs: {
        'router_builder|lib/routes.g.dart':
            decodedMatches(contains('deepLinkMap')),
      },
    );
  });
}
```

`test/generator/generator_rtconfig_test.dart`:

```dart
import 'package:build_test/build_test.dart';
import 'package:router_builder/builder.dart';
import 'package:test/test.dart';

import '_support.dart';

const _single = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());
}
''';

const _duplicate = '''
import 'package:router_builder/router_builder.dart';

@RTConfig()
const a = RoutePolicy(mustBeAuthorized: false);
@RTConfig()
const b = RoutePolicy(pushGlobally: true);
''';

const _nonConst = '''
import 'package:flutter/widgets.dart';
import 'package:router_builder/router_builder.dart';

@RTConfig()
final appRoutePolicy = RoutePolicy(mustBeAuthorized: someFlag());
bool someFlag() => false;
''';

void main() {
  test('single @RTConfig wires installDefaults to its value', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': _single}),
      rootPackage: 'router_builder',
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          contains('RouterBuilderConfig.setDefaults(appRoutePolicy)'),
        ),
      },
    );
  });

  test('duplicate @RTConfig fails the build', () {
    expect(
      testBuilder(generator(), assets({'lib/c.dart': _duplicate}),
          rootPackage: 'router_builder'),
      throwsA(isA<RouterBuilderError>()),
    );
  });

  test('non-const @RTConfig fails the build', () {
    expect(
      testBuilder(generator(), assets({'lib/c.dart': _nonConst}),
          rootPackage: 'router_builder'),
      throwsA(isA<RouterBuilderError>()),
    );
  });
}
```

- [ ] **Step 3: Run to verify failures**

Run: `flutter test test/generator/` (or `dart test test/generator/` if faster)
Expected: FAIL (old generator emits `MyRoutes`/`RouteInfoHelper`, bakes categories, logs conflicts instead of throwing, ignores top-level vars and `@RTConfig`, ignores options).

- [ ] **Step 4: Replace the generator (Part A - top of file: imports through extraction)**

Replace the entire contents of `lib/src/generators/generate_route_info_helper.dart`. Part A below is the first half of the new file; Part B (next step) is the remainder of the SAME file, appended directly after Part A.

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

/// Error thrown by the builder for unrecoverable generation problems
/// (deep-link key conflicts, invalid or duplicate `@RTConfig`).
class RouterBuilderError extends Error {
  /// Creates a builder error with a human-readable [message].
  RouterBuilderError(this.message);

  /// The failure description shown in build output.
  final String message;

  @override
  String toString() => 'RouterBuilderError: $message';
}

/// Mutable accumulator passed through library scanning.
class _Collected {
  final List<Map<String, Object?>> routes = [];
  final List<Map<String, Object?>> configs = [];
}

/// Factory referenced by `build.yaml`; reads [BuilderOptions].
Builder generateRouteInfoHelperBuilder(BuilderOptions options) {
  final c = options.config;
  return GenerateRouteInfoHelperBuilder(
    output: (c['output'] as String?) ?? 'lib/routes.g.dart',
    routeClassName: (c['route_class_name'] as String?) ?? 'Routes',
    helperClassName: (c['helper_class_name'] as String?) ?? 'RoutesHelper',
    failOnConflict: (c['fail_on_conflict'] as bool?) ?? true,
  );
}

/// Aggregating [Builder] that scans `lib/` for `@RT` routes and `@RTConfig`,
/// then emits a single helper file of statically-true route data plus
/// runtime-derived category getters.
class GenerateRouteInfoHelperBuilder implements Builder {
  /// Creates the builder. All parameters come from [BuilderOptions].
  GenerateRouteInfoHelperBuilder({
    this.output = 'lib/routes.g.dart',
    this.routeClassName = 'Routes',
    this.helperClassName = 'RoutesHelper',
    this.failOnConflict = true,
  });

  /// Output asset path, relative to the package root.
  final String output;

  /// Name of the generated route-constants class.
  final String routeClassName;

  /// Name of the generated helper class.
  final String helperClassName;

  /// Whether a deep-link key conflict fails the build.
  final bool failOnConflict;

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$package$': [output],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final collected = _Collected();
    final dartFiles = await buildStep.findAssets(Glob('lib/**.dart')).toList();
    for (final id in dartFiles) {
      if (await buildStep.resolver.isLibrary(id)) {
        final library = await buildStep.resolver.libraryFor(id);
        await _processLibrary(library, buildStep, collected);
      }
    }

    if (collected.configs.length > 1) {
      final refs = collected.configs.map((c) => c['ref']).join(', ');
      throw RouterBuilderError(
        'Found ${collected.configs.length} @RTConfig declarations ($refs). '
        'Exactly one is allowed.',
      );
    }

    final code = _formatGeneratedCode(collected);
    final outputId = AssetId(buildStep.inputId.package, output);
    await buildStep.writeAsString(outputId, code);
  }

  // -------------------------------------------------------------------------
  // DISCOVERY
  // -------------------------------------------------------------------------

  Future<void> _processLibrary(
    LibraryElement library,
    BuildStep buildStep,
    _Collected out,
  ) async {
    final importUri = (await buildStep.resolver.assetIdForElement(library)).uri;

    for (final cls in library.classes) {
      final className = cls.name;
      if (className == null) continue;
      for (final field in cls.fields) {
        if (!field.isStatic || !field.isPublic) continue;
        final fieldName = field.name;
        if (fieldName == null) continue;
        if (_hasAnnotation(field, 'RT')) {
          out.routes.add(
            await _extractRouteData(
              field,
              '$className.$fieldName',
              importUri,
              buildStep,
            ),
          );
        }
        if (_hasAnnotation(field, 'RTConfig')) {
          out.configs.add(_configRef('$className.$fieldName', importUri, field));
        }
      }
    }

    for (final variable in library.topLevelVariables) {
      if (!variable.isPublic) continue;
      final name = variable.name;
      if (name == null) continue;
      if (_hasAnnotation(variable, 'RT')) {
        out.routes.add(
          await _extractRouteData(variable, name, importUri, buildStep),
        );
      }
      if (_hasAnnotation(variable, 'RTConfig')) {
        out.configs.add(_configRef(name, importUri, variable));
      }
    }
  }

  bool _hasAnnotation(Element element, String name) {
    for (final annotation in element.metadata.annotations) {
      final el = annotation.element;
      if (el is ConstructorElement && el.enclosingElement.name == name) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?> _configRef(
    String ref,
    Uri importUri,
    VariableElement element,
  ) {
    if (!element.isConst) {
      throw RouterBuilderError(
        '@RTConfig on "$ref" must annotate a `const RoutePolicy`.',
      );
    }
    final typeName = element.type.element?.name;
    if (typeName != 'RoutePolicy') {
      throw RouterBuilderError(
        '@RTConfig on "$ref" must be a RoutePolicy (found ${typeName ?? 'unknown'}).',
      );
    }
    return {'ref': ref, 'importUri': importUri.toString()};
  }

  // -------------------------------------------------------------------------
  // EXTRACTION (DartObject-first with AST fallback; enum stays on AST)
  // -------------------------------------------------------------------------

  Future<Map<String, Object?>> _extractRouteData(
    VariableElement element,
    String ref,
    Uri importUri,
    BuildStep buildStep,
  ) async {
    final node = await buildStep.resolver.astNodeFor(
      element.firstFragment,
      resolve: true,
    );
    final init = (node is VariableDeclaration)
        ? node.initializer
        : null;
    final creation = init is InstanceCreationExpression ? init : null;
    final ctorName = creation?.constructorName.name?.name;
    final kind = ctorName == 'branch'
        ? 'branch'
        : ctorName == 'redirect'
            ? 'redirect'
            : 'standard';

    final value = element.computeConstantValue();

    final data = <String, Object?>{
      'ref': ref,
      'importUri': importUri.toString(),
      'routeName': value?.getField('name')?.toStringValue() ??
          _positionalString(creation),
      'path': value?.getField('_path')?.toStringValue() ??
          _namedString(creation, 'path'),
      'deepLinkNames': _stringList(value, 'deepLinkNames', creation),
      'kind': kind,
      'branchParentType': null,
      'branchParentType_type': null,
      'branchParentType_import': null,
      'branchIndex': value?.getField('branchIndex')?.toIntValue() ??
          _namedInt(creation, 'branchIndex'),
      'branchKey': value?.getField('branchKey')?.toStringValue() ??
          _namedString(creation, 'branchKey'),
      'isConst': element.isConst,
    };

    if (kind == 'branch') {
      _extractBranchParentType(data, creation);
    }
    return data;
  }

  void _extractBranchParentType(
    Map<String, Object?> data,
    InstanceCreationExpression? creation,
  ) {
    final expr = _namedExpr(creation, 'branchParentType');
    if (expr == null) return;
    data['branchParentType'] = expr.toSource();
    final element = expr.staticType?.element;
    if (element is EnumElement) {
      data['branchParentType_type'] = element.name;
      data['branchParentType_import'] = element.library.uri.toString();
    } else {
      throw RouterBuilderError(
        'branchParentType for ${data['ref']} must be an enum value.',
      );
    }
  }

  Expression? _positionalExpr(InstanceCreationExpression? creation) {
    if (creation == null) return null;
    for (final arg in creation.argumentList.arguments) {
      if (arg is! NamedExpression) return arg;
    }
    return null;
  }

  String? _positionalString(InstanceCreationExpression? creation) {
    final expr = _positionalExpr(creation);
    return expr is StringLiteral ? expr.stringValue : null;
  }

  Expression? _namedExpr(InstanceCreationExpression? creation, String name) {
    if (creation == null) return null;
    for (final arg in creation.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return arg.expression;
      }
    }
    return null;
  }

  String? _namedString(InstanceCreationExpression? creation, String name) {
    final expr = _namedExpr(creation, name);
    return expr is StringLiteral ? expr.stringValue : null;
  }

  int? _namedInt(InstanceCreationExpression? creation, String name) {
    final expr = _namedExpr(creation, name);
    return expr is IntegerLiteral ? expr.value : null;
  }

  List<String> _stringList(
    DartObject? value,
    String field,
    InstanceCreationExpression? creation,
  ) {
    final fromConst = value
        ?.getField(field)
        ?.toListValue()
        ?.map((e) => e.toStringValue())
        .whereType<String>()
        .toList();
    if (fromConst != null) return fromConst;
    final expr = _namedExpr(creation, field);
    if (expr is ListLiteral) {
      return expr.elements
          .whereType<StringLiteral>()
          .map((e) => e.stringValue)
          .whereType<String>()
          .toList();
    }
    return const [];
  }
```

Add this import to the Part A import block (DartObject lives here): `import 'package:analyzer/dart/constant/value.dart';` (place it first, before `ast.dart`). Part B continues the same class.

- [ ] **Step 5: Replace the generator (Part B - code generation, same file continued)**

Append directly after Part A (still inside `class GenerateRouteInfoHelperBuilder`, then close the class):

```dart
  // -------------------------------------------------------------------------
  // CODE GENERATION
  // -------------------------------------------------------------------------

  String _formatGeneratedCode(_Collected collected) {
    final code = _generateCode(collected);
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    return formatter.format(code);
  }

  String _generateCode(_Collected collected) {
    final routes = collected.routes;
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..writeln('//')
      ..writeln('// Run: dart run build_runner build')
      ..writeln()
      ..writeln('// ignore_for_file: type=lint')
      ..writeln();
    _writeImports(buffer, collected);
    _writeRoutesClass(buffer, routes);
    _writeHelperClass(buffer, collected);
    return buffer.toString();
  }

  void _writeImports(StringBuffer buffer, _Collected collected) {
    final uris = <String>{
      'package:dart_helper_utils/dart_helper_utils.dart',
      'package:router_builder/router_builder.dart',
    };
    for (final r in collected.routes) {
      uris.add(r['importUri'] as String);
      final bp = r['branchParentType_import'];
      if (bp is String && bp.isNotEmpty) uris.add(bp);
    }
    for (final c in collected.configs) {
      uris.add(c['importUri'] as String);
    }
    for (final uri in uris.toList()..sort()) {
      buffer.writeln("import '$uri';");
    }
    buffer.writeln();
  }

  void _writeRoutesClass(StringBuffer buffer, List<Map<String, Object?>> routes) {
    buffer
      ..writeln('/// Static constants for every defined route.')
      ..writeln('abstract class $routeClassName {');
    for (final r in routes) {
      final routeName = r['routeName'] as String?;
      if (routeName == null || routeName.isEmpty) continue;
      final ident = _safeIdentifier(routeName);
      final isConst = r['isConst'] == true;
      buffer.writeln(
        '  static ${isConst ? 'const' : 'final'} RouteInfo $ident = ${r['ref']};',
      );
    }
    buffer
      ..writeln('}')
      ..writeln();
  }

  void _writeHelperClass(StringBuffer buffer, _Collected collected) {
    final routes = collected.routes;
    buffer
      ..writeln('/// Categorized routes and deep-link utilities.')
      ..writeln('abstract class $helperClassName {')
      ..writeln(_generateBranchesMap(routes))
      ..writeln(_generateEnumBranchLists(routes))
      ..writeln(_generateAllRoutes(routes))
      ..writeln(_generateCategoryGetters())
      ..writeln(_generateDeepLinkMap(routes))
      ..writeln(_generateFromName())
      ..writeln(_generateDeepLinkHelpers())
      ..writeln(_generateBranchHelpers(routes))
      ..writeln(_generateInstallDefaults(collected.configs))
      ..writeln('}')
      ..writeln();
  }

  String _branchEnumType(List<Map<String, Object?>> branches) {
    if (branches.isEmpty) return 'Enum';
    final first = branches.first['branchParentType_type'] as String?;
    if (first == null) return 'Enum';
    final allSame =
        branches.every((b) => b['branchParentType_type'] == first);
    if (!allSame) {
      throw RouterBuilderError(
        'All branch routes must share a single branchParentType enum type.',
      );
    }
    return first;
  }

  String _generateBranchesMap(List<Map<String, Object?>> routes) {
    final branches = routes.where((r) => r['kind'] == 'branch').toList();
    final enumType = _branchEnumType(branches);
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final f in branches) {
      final parent = f['branchParentType'] as String?;
      if (parent != null) grouped.putIfAbsent(parent, () => []).add(f);
    }
    for (final g in grouped.values) {
      g.sort(
        (a, b) => ((a['branchIndex'] as int?) ?? 0)
            .compareTo((b['branchIndex'] as int?) ?? 0),
      );
    }
    final buffer = StringBuffer()
      ..writeln('  /// Branch routes grouped by shell enum value.')
      ..writeln(
        '  static final Map<$enumType, Map<int?, RouteInfo>> branches = {',
      );
    grouped.forEach((parent, list) {
      buffer.writeln('    $parent: {');
      for (final f in list) {
        buffer.writeln('      ${f['ref']}.branchIndex: ${f['ref']},');
      }
      buffer.writeln('    },');
    });
    buffer.writeln('  };');
    return buffer.toString();
  }

  String _generateEnumBranchLists(List<Map<String, Object?>> routes) {
    final branches = routes.where((r) => r['kind'] == 'branch').toList();
    if (branches.isEmpty) return '';
    _branchEnumType(branches);
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final f in branches) {
      final parent = f['branchParentType'] as String?;
      if (parent != null) grouped.putIfAbsent(parent, () => []).add(f);
    }
    for (final g in grouped.values) {
      g.sort(
        (a, b) => ((a['branchIndex'] as int?) ?? 0)
            .compareTo((b['branchIndex'] as int?) ?? 0),
      );
    }
    final buffer = StringBuffer();
    grouped.forEach((parent, list) {
      final valueName = parent.split('.').last;
      buffer
        ..writeln('  /// Branches for `$parent`.')
        ..writeln('  static final List<RouteInfo> ${valueName}Branches = [');
      for (final f in list) {
        buffer.writeln('    ${f['ref']},');
      }
      buffer
        ..writeln('  ];')
        ..writeln();
    });
    return buffer.toString().trimRight();
  }

  String _generateAllRoutes(List<Map<String, Object?>> routes) {
    final nonBranch = routes
        .where((r) => r['kind'] != 'branch')
        .map((r) => '    ${r['ref']},')
        .join('\n');
    return '''
  /// Every annotated route (branches, standard, popup, global, redirect-only).
  static final List<RouteInfo> allRoutes = [
    ...branches.values.expand((m) => m.values),
$nonBranch
  ];
''';
  }

  String _generateCategoryGetters() => '''
  /// Standard routes (non-branch, non-global, non-redirect).
  static List<RouteInfo> get normalRoutes => allRoutes
      .where((r) => !r.isBranch && !r.forRedirectionOnly && !r.pushGlobally)
      .toList();

  /// Routes pushed on the root navigator.
  static List<RouteInfo> get globalRoutes => allRoutes
      .where((r) => r.pushGlobally && !r.isBranch && !r.forRedirectionOnly)
      .toList();

  /// Popup routes.
  static List<RouteInfo> get popupRoutes =>
      allRoutes.where((r) => r.isPopupRoute).toList();

  /// Top-level-only routes.
  static List<RouteInfo> get topLevelRoutes =>
      allRoutes.where((r) => r.isTopLevelOnly).toList();

  /// Routes that require authorization.
  static List<RouteInfo> get authorizedRoutes =>
      allRoutes.where((r) => r.mustBeAuthorized).toList();

  /// Redirect-only routes.
  static List<RouteInfo> get redirectRoutes =>
      allRoutes.where((r) => r.forRedirectionOnly).toList();
''';

  Set<String> _routeKeys(Map<String, Object?> r) {
    final keys = <String>{};
    final name = r['routeName'] as String?;
    if (name != null && name.isNotEmpty) keys.add(name);
    keys.addAll(r['deepLinkNames'] as List<String>? ?? const []);
    final path = r['path'] as String?;
    if (path != null && path.isNotEmpty) {
      final clean = path.startsWith('/') ? path.substring(1) : path;
      final seg = RegExp('^([^/:]+)').firstMatch(clean)?.group(1);
      if (seg != null && seg.isNotEmpty) keys.add(seg);
    }
    return keys;
  }

  String _generateDeepLinkMap(List<Map<String, Object?>> routes) {
    final map = <String, String>{};
    final conflicts = <String, List<String>>{};
    for (final r in routes) {
      final ref = r['ref'] as String;
      for (final key in _routeKeys(r)) {
        if (map.containsKey(key)) {
          conflicts.putIfAbsent(key, () => [map[key]!]).add(ref);
        } else {
          map[key] = ref;
        }
      }
    }
    if (conflicts.isNotEmpty) {
      final detail = conflicts.entries
          .map((e) => "  '${e.key}' used by ${e.value.join(', ')}")
          .join('\n');
      if (failOnConflict) {
        throw RouterBuilderError(
          'Deep-link key conflict(s):\n$detail\n'
          'Each route name, first path segment, and deepLinkNames alias must be '
          'unique. Rename the route, change its path, or adjust deepLinkNames.',
        );
      }
      log.warning('Deep-link key conflict(s) (keeping first):\n$detail');
    }
    final buffer = StringBuffer()
      ..writeln(
        '  /// Lookup by deep-link key (route name, first path segment, alias).',
      )
      ..writeln('  static final Map<String, RouteInfo> deepLinkMap = {');
    for (final key in map.keys.toList()..sort()) {
      buffer.writeln("    '$key': ${map[key]},");
    }
    buffer.writeln('  };');
    return buffer.toString();
  }

  String _generateFromName() => '''
  /// Returns the [RouteInfo] for [name], or null.
  static RouteInfo? fromName(String? name) =>
      allRoutes.firstWhereOrNull((route) => route.name == name);
''';

  String _generateDeepLinkHelpers() => '''
  /// Resolves a deep-link URI into a [RouteInfo] and [RouteArgs].
  static DeepLinkMatch? resolveDeepLink(
    Uri incoming, {
    Iterable<String> allowedHosts = const [],
  }) {
    final normalized =
        DeepLinkMatcher.normalizeToAppPath(incoming, hosts: allowedHosts);
    return const DeepLinkMatcher()
        .match(normalized, allRoutes, original: incoming);
  }

  /// Normalizes an incoming deep-link URI to an app-internal path.
  static Uri normalizeToAppPath(
    Uri incoming, {
    Iterable<String> allowedHosts = const [],
  }) =>
      DeepLinkMatcher.normalizeToAppPath(incoming, hosts: allowedHosts);
''';

  String _generateBranchHelpers(List<Map<String, Object?>> routes) {
    final enumType =
        _branchEnumType(routes.where((r) => r['kind'] == 'branch').toList());
    return '''
  /// Branch routes for [shell], or null.
  static Map<int?, RouteInfo>? branchesFor($enumType shell) => branches[shell];

  /// All branch routes across shells.
  static List<RouteInfo> allBranches() =>
      branches.values.expand((m) => m.values).toList();

  /// Branch route for [shell] at [index], or null.
  static RouteInfo? branchByIndex($enumType shell, int? index) =>
      branches[shell]?[index];

  /// Whether [route] belongs to [shell].
  static bool isRouteInShell(RouteInfo route, $enumType shell) =>
      branches[shell]?.containsValue(route) ?? false;

  /// Finds a branch route by its [key].
  static RouteInfo? branchByKey(String key) => branches.values
      .expand((m) => m.values)
      .firstWhereOrNull((route) => route.branchKey == key);
''';
  }

  String _generateInstallDefaults(List<Map<String, Object?>> configs) {
    if (configs.isEmpty) {
      return '''
  /// Installs global route defaults. No @RTConfig was declared, so this only
  /// marks configuration as initialized; built-in defaults remain in effect.
  static void installDefaults() {
    RouterBuilderConfig.markConfigured();
  }
''';
    }
    final ref = configs.first['ref'];
    return '''
  /// Installs the app's @RTConfig policy as global defaults. Call once in main().
  static void installDefaults() {
    RouterBuilderConfig.setDefaults($ref);
    RouterBuilderConfig.markConfigured();
  }
''';
  }

  String _safeIdentifier(String name) {
    var safe = name.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    if (RegExp('^[0-9]').hasMatch(safe)) safe = '_$safe';
    return safe;
  }
}
```

- [ ] **Step 6: Export `RouterBuilderError` from the build entrypoint**

`lib/builder.dart`:

```dart
/// Build entrypoint for router_builder's code generator.
library;

export 'src/generators/generate_route_info_helper.dart'
    show generateRouteInfoHelperBuilder, RouterBuilderError;
```

- [ ] **Step 7: Run the generator tests**

Run: `flutter test test/generator/`
Expected: PASS. If `build_test` resolution under `flutter test` is slow or flaky, run `dart test test/generator/` instead (both are valid; document in the test header).

- [ ] **Step 8: Analyze and commit**

Run: `flutter analyze`
Expected: 0 errors.

```bash
git add -A
git commit -m "feat: rewrite generator (options, runtime categories, top-level @RT, @RTConfig, conflict-as-error)"
```

---

## Phase 5 - Deep-link correctness and security (D13, D14)

### Task 5.1: Exact-or-suffix host matching; pin resolved gating and redirect resolution

The `deepLinkPushGlobally`-driven `_buildArgs` already landed in Task 2.4. This task fixes the substring host footgun and pins (with tests) the resolved `deepLinkAllowed` gating and redirect-route resolution that fall out of the v3 `RouteInfo`.

**Files:**
- Modify: `lib/src/deeplink/deep_link_matcher.dart` (`normalizeToAppPath` host check only)
- Test: `test/deeplink/deep_link_matcher_test.dart`

- [ ] **Step 1: Write the failing/pinning tests**

`test/deeplink/deep_link_matcher_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:router_builder/router_builder.dart';

void main() {
  setUp(RouterBuilderConfig.reset);
  tearDown(RouterBuilderConfig.reset);

  group('normalizeToAppPath host matching', () {
    test('accepts exact host and subdomains', () {
      expect(
        DeepLinkMatcher.normalizeToAppPath(
          Uri.parse('https://myapp.com/users/7'),
          hosts: ['myapp.com'],
        ).path,
        '/users/7',
      );
      expect(
        DeepLinkMatcher.normalizeToAppPath(
          Uri.parse('https://www.myapp.com/users/7'),
          hosts: ['myapp.com'],
        ).path,
        '/users/7',
      );
    });

    test('rejects look-alike substring hosts (security)', () {
      // evil-myapp.com is NOT allowed; the host is promoted to a path segment.
      expect(
        DeepLinkMatcher.normalizeToAppPath(
          Uri.parse('https://evil-myapp.com/users/7'),
          hosts: ['myapp.com'],
        ).path,
        '/evil-myapp.com/users/7',
      );
    });
  });

  group('match', () {
    test('resolves a template route and applies deepLinkPushGlobally', () {
      const route = RouteInfo('user', path: '/users/:id', child: SizedBox());
      final match =
          const DeepLinkMatcher().match(Uri.parse('/users/7'), const [route]);
      expect(match, isNotNull);
      expect(match!.args.id, '7');
      expect(match.args.effectivePushGlobally, isTrue);
    });

    test('honors a global deepLinkAllowed:false default (resolved gating)', () {
      RouterBuilderConfig.setDefaults(
        const RoutePolicy(deepLinkAllowed: false),
      );
      const route = RouteInfo('user', path: '/users/:id', child: SizedBox());
      final match =
          const DeepLinkMatcher().match(Uri.parse('/users/7'), const [route]);
      expect(match, isNull);
    });

    test('resolves redirect-only routes', () {
      const redirect = RouteInfo.redirect('gate', redirect: _to, path: '/gate');
      final match =
          const DeepLinkMatcher().match(Uri.parse('/gate'), const [redirect]);
      expect(match, isNotNull);
      expect(match!.route.name, 'gate');
    });
  });
}

String? _to(BuildContext c, RouteArgs? a) => null;
```

- [ ] **Step 2: Run to verify the security test fails**

Run: `flutter test test/deeplink/deep_link_matcher_test.dart`
Expected: the substring-rejection test FAILS (today `.contains` accepts `evil-myapp.com`); the others should pass.

- [ ] **Step 3: Replace the host check in `normalizeToAppPath`**

In `lib/src/deeplink/deep_link_matcher.dart`, replace the block at the current lines 35-44:

```dart
    final lowerHosts =
        hosts.map((host) => host.toLowerCase()).toList(growable: false);
    final scheme = incoming.scheme.toLowerCase();
    final host = incoming.host.toLowerCase();
    final params =
        incoming.queryParameters.isEmpty ? null : incoming.queryParameters;

    if ((scheme == 'http' || scheme == 'https') &&
        lowerHosts.any(
          (allowed) => host == allowed || host.endsWith('.$allowed'),
        )) {
      final path = incoming.path.isEmpty ? '/' : incoming.path;
      return Uri(path: path, queryParameters: params);
    }
```

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/deeplink/deep_link_matcher_test.dart && flutter analyze`
Expected: all PASS; 0 analyzer errors.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "fix(deeplink): exact-or-suffix host matching; pin resolved gating and redirect resolution"
```

---

## Phase 6 - Build config finalize (D12)

### Task 6.1: Flip generated output to `routes.g.dart`

**Files:**
- Modify: `build.yaml`

- [ ] **Step 1: Update `build_extensions` to the v3 default**

`build.yaml`:

```yaml
builders:
  generate_route_info_helper:
    import: "package:router_builder/builder.dart"
    builder_factories: [ "generateRouteInfoHelperBuilder" ]
    build_extensions: { r'$package$': [ "lib/routes.g.dart" ] }
    auto_apply: dependents
    build_to: source
options:
  # route_class_name: Routes
  # helper_class_name: RoutesHelper
  # output: lib/routes.g.dart        # if changed, also update build_extensions above
  # fail_on_conflict: true
```

(The `options:` block is commented documentation of the available keys; consumers uncomment to override. If `output` is changed, `build_extensions` must be set to the same path - a build_runner requirement for `$package$` builders.)

- [ ] **Step 2: Analyze (no Dart change; sanity only)**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add build.yaml
git commit -m "build: default generated output to lib/routes.g.dart"
```

---

## Phase 7 - Example app and comprehensive generated golden (user-requested)

### Task 7.1: Runnable example whose routes exercise every generator case once

The example's `app_routes.dart` covers each supported case exactly once: standard `child`/`builder`/`pageBuilder`, popup, global, public, top-level-only, path + deepLinkNames, redirect-only, a 3-branch shell enum, a top-level const route, and an `@RTConfig`. Running `build_runner` produces a full, non-repetitive `routes.g.dart` (committed as a living golden + smoke test).

**Files:**
- Create: `example/pubspec.yaml`, `example/analysis_options.yaml`, `example/lib/routes/app_routes.dart`, `example/lib/main.dart`
- Generate + commit: `example/lib/routes.g.dart`

- [ ] **Step 1: Create the example package manifest**

`example/pubspec.yaml`:

```yaml
name: router_builder_example
description: Example app demonstrating router_builder v3.
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter
  router_builder:
    path: ../

dev_dependencies:
  build_runner: ^2.13.1
  flutter_lints: ^6.0.0
  flutter_test:
    sdk: flutter
```

`example/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    public_member_api_docs: false

analyzer:
  exclude:
    - "**/*.g.dart"
```

- [ ] **Step 2: Write the comprehensive route declarations**

`example/lib/routes/app_routes.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:router_builder/router_builder.dart';

/// Shell tabs for bottom navigation (exercises branch routes + enum grouping).
enum AppShell { home, search, profile }

/// App-wide route defaults, installed via RoutesHelper.installDefaults().
@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);

/// A top-level route (exercises top-level @RT discovery, D15).
@RT()
const settings = RouteInfo(
  'settings',
  child: SizedBox(),
  policy: RoutePolicy(isTopLevelOnly: true),
);

/// Class-hosted routes covering the remaining cases.
abstract class AppRoutes {
  /// Standard route built from a static child.
  @RT()
  static const home = RouteInfo('home', child: SizedBox());

  /// Standard route built from a builder.
  @RT()
  static const dashboard = RouteInfo('dashboard', builder: _dashboard);

  /// Standard route with a custom page, a path template, and deep-link aliases.
  @RT()
  static const details = RouteInfo(
    'details',
    path: '/items/:id',
    pageBuilder: _detailsPage,
    deepLinkNames: ['item', 'product'],
  );

  /// Global route (pushed on the root navigator).
  @RT()
  static const adminPanel = RouteInfo(
    'admin',
    child: SizedBox(),
    policy: RoutePolicy.global,
  );

  /// Public route (no auth required).
  @RT()
  static const login = RouteInfo(
    'login',
    child: SizedBox(),
    policy: RoutePolicy.public,
  );

  /// Popup route.
  @RT()
  static const confirmSheet = RouteInfo(
    'confirm',
    child: SizedBox(),
    policy: RoutePolicy.popup,
  );

  /// Redirect-only route.
  @RT()
  static const splashGate = RouteInfo.redirect(
    'splash',
    redirect: _gate,
    path: '/splash',
  );

  /// Home shell branch.
  @RT()
  static const homeTab = RouteInfo.branch(
    'homeTab',
    branchIndex: 0,
    branchKey: '_homeNav',
    branchParentType: AppShell.home,
    child: SizedBox(),
  );

  /// Search shell branch.
  @RT()
  static const searchTab = RouteInfo.branch(
    'searchTab',
    branchIndex: 1,
    branchKey: '_searchNav',
    branchParentType: AppShell.search,
    child: SizedBox(),
  );

  /// Profile shell branch.
  @RT()
  static const profileTab = RouteInfo.branch(
    'profileTab',
    branchIndex: 2,
    branchKey: '_profileNav',
    branchParentType: AppShell.profile,
    child: SizedBox(),
  );
}

Widget _dashboard(BuildContext context, RouteArgs? args) => const SizedBox();

Page<dynamic> _detailsPage(BuildContext context, RouteArgs? args) =>
    const MaterialPage<dynamic>(child: SizedBox());

String? _gate(BuildContext context, RouteArgs? args) => AppRoutes.login.path;
```

- [ ] **Step 3: Write a minimal runnable app**

`example/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:router_builder/router_builder.dart';
import 'package:router_builder_example/routes.g.dart';

void main() {
  RoutesHelper.installDefaults();
  runApp(const ExampleApp());
}

/// Root widget of the example.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: HomeScreen());
}

/// Demonstrates the generated helper at runtime.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final match = RoutesHelper.resolveDeepLink(
      Uri.parse('https://example.com/items/42'),
      allowedHosts: const ['example.com'],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('router_builder example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total routes: ${RoutesHelper.allRoutes.length}'),
            Text('Global routes: ${RoutesHelper.globalRoutes.length}'),
            Text('Authorized routes: ${RoutesHelper.authorizedRoutes.length}'),
            Text('Redirect routes: ${RoutesHelper.redirectRoutes.length}'),
            Text('Branches: ${RoutesHelper.allBranches().length}'),
            Text(
              'Deep link -> ${match?.route.name ?? 'none'} '
              '(id=${match?.args.id})',
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Generate and verify the example builds**

Run:
```bash
cd /Users/omarhanafy/Development/MyProjects/router_builder/example
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```
Expected: `example/lib/routes.g.dart` is created; analyzer reports 0 errors. Open `routes.g.dart` and confirm it contains `class Routes`, `class RoutesHelper`, `branches` keyed by `AppShell`, `homeBranches`/`searchBranches`/`profileBranches`, `allRoutes` including `AppRoutes.splashGate`, all six category getters, a `deepLinkMap` with `item`/`product`/`items`, and `installDefaults()` calling `setDefaults(appRoutePolicy)`.

- [ ] **Step 5: Commit (including the generated golden)**

```bash
cd /Users/omarhanafy/Development/MyProjects/router_builder
git add example
git commit -m "docs(example): runnable example covering every generator case + generated routes.g.dart"
```

---

### Task 7.2: Hermetic generator golden test (all cases in one file)

**Files:**
- Test: `test/generator/generator_golden_test.dart`

- [ ] **Step 1: Write the golden test**

`test/generator/generator_golden_test.dart` (the fixture mirrors the example's route shapes so one generation exercises every path):

```dart
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import '_support.dart';

const _comprehensive = '''
import 'package:flutter/material.dart';
import 'package:router_builder/router_builder.dart';

enum AppShell { home, search, profile }

@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false);

@RT()
const settings = RouteInfo('settings', child: SizedBox(),
    policy: RoutePolicy(isTopLevelOnly: true));

abstract class AppRoutes {
  @RT()
  static const home = RouteInfo('home', child: SizedBox());
  @RT()
  static const dashboard = RouteInfo('dashboard', builder: _b);
  @RT()
  static const details = RouteInfo('details', path: '/items/:id',
      pageBuilder: _p, deepLinkNames: ['item', 'product']);
  @RT()
  static const adminPanel =
      RouteInfo('admin', child: SizedBox(), policy: RoutePolicy.global);
  @RT()
  static const login =
      RouteInfo('login', child: SizedBox(), policy: RoutePolicy.public);
  @RT()
  static const confirmSheet =
      RouteInfo('confirm', child: SizedBox(), policy: RoutePolicy.popup);
  @RT()
  static const splashGate =
      RouteInfo.redirect('splash', redirect: _g, path: '/splash');
  @RT()
  static const homeTab = RouteInfo.branch('homeTab', branchIndex: 0,
      branchKey: '_h', branchParentType: AppShell.home, child: SizedBox());
  @RT()
  static const searchTab = RouteInfo.branch('searchTab', branchIndex: 1,
      branchKey: '_s', branchParentType: AppShell.search, child: SizedBox());
  @RT()
  static const profileTab = RouteInfo.branch('profileTab', branchIndex: 2,
      branchKey: '_p', branchParentType: AppShell.profile, child: SizedBox());
}

Widget _b(BuildContext c, RouteArgs? a) => const SizedBox();
Page<dynamic> _p(BuildContext c, RouteArgs? a) =>
    const MaterialPage<dynamic>(child: SizedBox());
String? _g(BuildContext c, RouteArgs? a) => AppRoutes.login.path;
''';

void main() {
  test('one generation covers every supported case', () async {
    await testBuilder(
      generator(),
      assets({'lib/app_routes.dart': _comprehensive}),
      rootPackage: 'router_builder',
      outputs: {
        'router_builder|lib/routes.g.dart': decodedMatches(
          allOf(
            // route constants (standard, top-level, branch, redirect)
            contains('RouteInfo home = AppRoutes.home'),
            contains('RouteInfo settings = settings'),
            contains('RouteInfo splash = AppRoutes.splashGate'),
            // branch map + per-enum lists keyed by the shell enum
            contains('Map<AppShell, Map<int?, RouteInfo>> branches'),
            contains('homeBranches'),
            contains('searchBranches'),
            contains('profileBranches'),
            // allRoutes includes redirect-only
            contains('AppRoutes.splashGate'),
            // all runtime category getters
            contains('get normalRoutes'),
            contains('get globalRoutes'),
            contains('get popupRoutes'),
            contains('get topLevelRoutes'),
            contains('get authorizedRoutes'),
            contains('get redirectRoutes'),
            // deep-link keys: name, aliases, path segment
            contains("'details':"),
            contains("'item':"),
            contains("'product':"),
            contains("'items':"),
            // @RTConfig wiring
            contains('RouterBuilderConfig.setDefaults(appRoutePolicy)'),
          ),
        ),
      },
    );
  });
}
```

- [ ] **Step 2: Run the golden test**

Run: `flutter test test/generator/generator_golden_test.dart`
Expected: PASS. (If a `contains` fails, the generator output differs from the spec - fix the generator, not the assertion, unless the assertion text itself is wrong.)

- [ ] **Step 3: Commit**

```bash
git add test/generator/generator_golden_test.dart
git commit -m "test: hermetic generator golden covering every supported case"
```

---

## Phase 8 - Documentation (spec section 12)

### Task 8.1: CHANGELOG 3.0.0 entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Prepend the 3.0.0 entry**

Insert directly after the `# CHANGELOG` heading (before `## 2.1.0`):

```markdown
## 3.0.0

Major release. See MIGRATION_GUIDE.md for the full v2 -> v3 guide.

### Breaking
- `RoutePolicy` is now the single home for cascading behavior (9 fields). Flat
  behavioral params/getters on `RouteInfo` and `RouteArgs` are removed; set them
  via `policy:` and read them via the resolved getters.
- `isGlobalOnly` renamed to `pushGlobally` everywhere.
- `RouteArgs` has one constructor (the private clone is gone); `isIdSlug` is
  removed (detect slug-vs-id from the value at the gate).
- Package layout moved under `lib/src/`; import only
  `package:router_builder/router_builder.dart`. Deep imports
  (`package:router_builder/models/...`) and `models/models.dart` are gone.
- `build.yaml` must import `package:router_builder/builder.dart`.
- Generated output defaults to `lib/routes.g.dart` with classes `Routes` and
  `RoutesHelper` (was `lib/route_info_helper.dart`, `MyRoutes`,
  `RouteInfoHelper`). Override via builder options if you prefer the old names.
- Deep-link host matching is now exact-or-suffix (was substring); verify your
  allowed-hosts list.
- Deep-link key conflicts now fail the build by default (`fail_on_conflict`).
- Builder typedefs unified to `(BuildContext, RouteArgs?)`.
- `RouterBuilderConfig.defaults` is read-only; use `setDefaults(RoutePolicy)`.

### Added
- `RoutePolicy.merge`/`copyWith`/`report` and `global`/`public`/`popup` presets.
- `RouterBuilderConfig` complete defaults, `reset`, `isConfigured`,
  `markConfigured`.
- Same-named resolved getters on `RouteInfo`; `effectiveX` getters on
  `RouteArgs`; branch/redirect structural constraints (force + debug assert).
- Runtime-derived generated categories (`normalRoutes`, `globalRoutes`,
  `popupRoutes`, `topLevelRoutes`, `authorizedRoutes`, `redirectRoutes`) that
  cannot drift from installed defaults; `allRoutes` now includes redirect-only
  routes.
- Configurable generator (`output`, `route_class_name`, `helper_class_name`,
  `fail_on_conflict`); `@RT` discovery now includes top-level consts/finals.
- `@RTConfig` annotation + generated `RoutesHelper.installDefaults()`.
- `deepLinkPushGlobally` policy field (default true); deep-link push-global is
  now policy-driven.
- JSON-safe `report()` on `RoutePolicy`/`RouteInfo`/`RouteArgs`.
- First test suite and a runnable `example/`.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for 3.0.0"
```

---

### Task 8.2: Migration guide (v2 -> v3)

**Files:**
- Modify: `MIGRATION_GUIDE.md`

- [ ] **Step 1: Prepend a v3 section**

Insert after the `# Router Builder - Deep Link Migration Guide` heading, before `## Overview`:

```markdown
## Migrating from v2 to v3

| v2 | v3 |
|----|----|
| `RouteInfo('x', mustBeAuthorized: false, isGlobalOnly: true)` | `RouteInfo('x', policy: RoutePolicy(mustBeAuthorized: false, pushGlobally: true))` |
| `RouteArgs(r, pushGlobally: true, duplicateBehavior: ...)` | `RouteArgs(r, policy: RoutePolicy(pushGlobally: true, duplicateBehavior: ...))` |
| `route.isGlobalOnly ?? false` | `route.pushGlobally` |
| `route.visibleNavBar` / `route.shouldReplaceAll` | unchanged (resolved getters) |
| `(route.isGlobalOnly ?? false) \|\| args.effectivePushGlobally` | `args.effectivePushGlobally` |
| `DialogArgs(... super.pushGlobally ...)` | `DialogArgs(... super.policy ...)` |
| `import 'package:router_builder/models/models.dart'` | `import 'package:router_builder/router_builder.dart'` |
| `import 'route_info_helper.dart'`; `MyRoutes.x` / `RouteInfoHelper` | `import 'routes.g.dart'`; `Routes.x` / `RoutesHelper` (or pin old names via builder options) |
| build.yaml imports the generator path | imports `package:router_builder/builder.dart` |
| `RouteArgs(..., isIdSlug: true)` | detect via `int.tryParse(args.id ?? '')`, or a `RouteArgs` subclass field |
| deep-link allowed hosts (substring match) | verify the list; matching is now exact-or-suffix |
| `RouterBuilderConfig.setDefaults(mustBeAuthorized: false)` | `RouterBuilderConfig.setDefaults(const RoutePolicy(mustBeAuthorized: false))`, or `@RTConfig` + `RoutesHelper.installDefaults()` |

Global defaults: declare one `@RTConfig() const appRoutePolicy = RoutePolicy(...)`
and call `RoutesHelper.installDefaults()` once at the start of `main()`.
```

- [ ] **Step 2: Commit**

```bash
git add MIGRATION_GUIDE.md
git commit -m "docs: v2->v3 migration guide"
```

---

### Task 8.3: README updates

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Mechanical identifier swaps**

Apply these replacements across `README.md` (replace-all):
- `route_info_helper.dart` -> `routes.g.dart`
- `MyRoutes` -> `Routes`
- `RouteInfoHelper` -> `RoutesHelper`

- [ ] **Step 2: Fix the `isGlobalOnly` reference**

Replace the list item ``- `RouteInfo.isGlobalOnly` `` (README line ~231) with:

```markdown
- `RouteInfo.pushGlobally` (resolved; set via `policy: RoutePolicy(pushGlobally: ...)`)
```

- [ ] **Step 3: Add a global-defaults snippet**

Add a short subsection (near the configuration/usage area) documenting `@RTConfig`:

```markdown
### Global defaults (`@RTConfig`)

Declare one app-wide policy and install it in `main()`:

```dart
@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false, deepLinkAllowed: true);

void main() {
  RoutesHelper.installDefaults(); // applies appRoutePolicy as global defaults
  runApp(const MyApp());
}
```

Per-route and per-call overrides win over these defaults; structural constraints
(branch/redirect) always win last.
```

- [ ] **Step 4: Add a "Migrating to v3" pointer**

Add near the top of `README.md`:

```markdown
> **Upgrading from v2?** See the v2 -> v3 table in `MIGRATION_GUIDE.md`. Key
> changes: one `RoutePolicy` for all behavior, `import
> 'package:router_builder/router_builder.dart'` only, generated `Routes` /
> `RoutesHelper` in `routes.g.dart`.
```

- [ ] **Step 5: Verify and commit**

Run: `grep -nE 'MyRoutes|RouteInfoHelper|route_info_helper|isGlobalOnly' README.md` -> expect no stale matches (except inside the migration pointer, if any).

```bash
git add README.md
git commit -m "docs: update README for v3 API"
```

---

## Phase 9 - Final verification

### Task 9.1: Whole-package green, regenerate example, format

**Files:** none new (fix-ups only)

- [ ] **Step 1: Analyze the whole package**

Run: `cd /Users/omarhanafy/Development/MyProjects/router_builder && flutter analyze`
Expected: 0 errors, 0 warnings in `lib/`. Per CLAUDE.md, for a publishable package treat warnings as must-fix. Fix any stragglers.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all tests pass (smoke, models, resolution matrix, deep-link, generator, golden). If generator tests are slow/flaky under `flutter test`, also confirm `dart test test/generator/` is green.

- [ ] **Step 3: Regenerate the example and analyze it**

Run:
```bash
cd example && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && cd ..
```
Expected: `example/lib/routes.g.dart` regenerates with no diff churn beyond intended; example analyzes clean. Commit the regenerated file only if it changed.

- [ ] **Step 4: Format**

Run: `dart format .`
Expected: formats sources; commit any formatting changes.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: v3 final analyze/test/format pass"
```

---

## Self-review (run against the spec before executing)

**1. Spec coverage (D1-D17):**
- D1 9-field `RoutePolicy` -> Task 2.2. D2 no new type; resolution via getters -> 2.2/2.4. D3 complete encapsulated defaults -> 2.3. D4 resolved getters -> 2.4. D5 constructors drop flat params -> 2.4. D6 one `RouteArgs` ctor, subclassable -> 2.4. D7 runtime-derived categories -> 4.1 (Part B). D8 `@RTConfig` + install wiring + duplicate error -> 3.1 + 4.1. D9 `isGlobalOnly` -> `pushGlobally` -> 2.4 + 8.x. D10 `lib/src` + barrel + builder.dart -> 1.1. D11 builder options -> 4.1. D12 `routes.g.dart`/`Routes`/`RoutesHelper` -> 4.1 + 6.1. D13 host exact-or-suffix + conflict fails build + `deepLinkPushGlobally` -> 5.1 + 4.1 + 2.4. D14 `allRoutes` includes redirect -> 4.1 + 5.1. D15 top-level `@RT` discovery -> 4.1. D16 unify typedefs, drop `isIdSlug`, drop stale `replaceAll` -> 2.4 + 4.1. D17 JSON-safe `report()` -> 2.2/2.4.
- Testing strategy (spec section 14): precedence matrix -> `resolution_matrix_test`; merge/policy -> `route_policy_test`; config -> `router_config_test`; generator (runtime getters, deepLinkMap, conflict-as-error, options, top-level discovery, `@RTConfig` errors) -> `test/generator/*`; deep-link matcher -> `deep_link_matcher_test`; equality -> model tests; `report()` encodability -> model tests.

**2. Placeholder scan:** No "TBD"/"TODO"/"similar to above". Every code step shows real code; every public member carries a `///` doc (the repo lints `public_member_api_docs: error`). The only "verify at execution" note is the analyzer `value.dart` import for `DartObject` (resolved by adding the import in Task 4.1 Step 4).

**3. Type consistency:** `RoutePolicy` 9 fields and their names are identical across `merge`/`copyWith`/`toMap`/`props`/`RouterBuilderConfig._builtInDefaults`/the resolved + effective getters/`constrain`. Generator data keys (`ref`, `routeName`, `path`, `deepLinkNames`, `kind`, `branchParentType*`, `branchIndex`, `branchKey`, `isConst`) are produced in `_extractRouteData` and consumed only by the emitters. `RouterBuilderError`, `generateRouteInfoHelperBuilder`, `installDefaults`, `Routes`/`RoutesHelper` names are used consistently in code and tests.

## Verification (end-to-end)

1. `flutter analyze` -> 0 errors/warnings in `lib/`.
2. `flutter test` -> all suites green; resolution matrix proves args > route > defaults > built-ins precedence with constraints last.
3. `cd example && dart run build_runner build --delete-conflicting-outputs` -> regenerates `routes.g.dart` containing every case once; `flutter analyze` and `flutter run` (or build) succeed.
4. Generator golden + conflict + `@RTConfig` tests prove: runtime categories, redirect inclusion, build-failing conflicts, and `@RTConfig` validation.
5. Deep-link tests prove exact-or-suffix host security and resolved `deepLinkAllowed` gating.

## Execution handoff

This plan also belongs at `docs/superpowers/plans/2026-06-09-router-builder-v3.md`; mirror it there once plan mode exits (only the plan file is editable inside plan mode).

Recommended execution: **subagent-driven** (superpowers:subagent-driven-development) - one fresh subagent per task, review between tasks. Phases are ordered so every commit compiles and is tested; do not reorder past a dependency (models -> generator/deep-link -> example).

Per CLAUDE.md: run `dart analyze`/`flutter analyze` after Dart edits, `dart format .` for lint fixes, never discard local changes without asking, and commit only the messages above (no co-author/self attribution).

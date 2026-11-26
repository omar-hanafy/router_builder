# Router Builder - Migration Guide

This guide collects everything you need to move between major versions of
`router_builder`.

**How it is organized**

- The newest migration comes first. Older ones follow, then a historical
  appendix.
- Each migration has the same shape: **What changed -> Automated codemods ->
  Manual steps -> Regenerate -> Verify**.
- "Automated codemods" are mechanical, safe text replacements applied by a
  script in `tool/`. "Manual steps" are the changes that need your judgement;
  the script never touches them.
- A reusable skeleton lives at the bottom (["Template for future
  migrations"](#template-for-future-migrations)) so every release documents its
  upgrade path the same way.

---

## v3 -> v4

The v4 runtime and the code generator ship in separate packages. The generator
is now `router_builder_generator`.

Route declarations and application imports of `package:router_builder/router_builder.dart`
work as before. Custom builders that import or export the old Dart builder
library must update that URI. Start the hosted upgrade once both packages are
available at 4.0.0.

### Why

Until v4, `router_builder` declared `analyzer`, `build`, `source_gen`, and
`dart_style` as regular **`dependencies`**. Keeping the generator's code out of
the runtime barrel stopped those packages from being *imported* by an app, but
it did not stop pub's solver from having to *resolve* them. Two consequences:

- Every app that depended on `router_builder` carried `analyzer` in its
  production dependency graph, and `router_builder`'s upper bound capped what
  the app could upgrade to - `build_runner`, `build`, and `dart_style`
  included.
- Any package that depended on `router_builder` passed that constraint on to
  *its* consumers transitively, because regular dependencies are transitive.

In v4 the runtime package depends only on `flutter`, `dart_helper_utils`, and
`equatable`. The generator is a build-time `dev_dependency`, and
`dev_dependencies` apply only within the consuming project. A package that
uses the runtime no longer passes the generator's constraints on to its users.

### Updating dependencies

Applications that regenerate routes need these two constraints. Applications
that ship an existing generated file can update the runtime alone.

```yaml
dependencies:
  router_builder: ^4.0.0

dev_dependencies:
  router_builder_generator: ^4.0.0
```

Keep your existing `build_runner` dependency. If your own package's published
builder imports or re-exports the generator from `lib/`, declare
`router_builder_generator` in that package's regular `dependencies` so its
consumers can resolve the builder.

### Applying the YAML changes

For a project that regenerates routes, run the bundled script from the app
directory. It requires Ruby with its standard YAML library.

```bash
script=/path/to/router_builder/tool/migrate_to_v4.sh
"$script"
"$script" --write
```

The first command previews a diff. The second updates hosted, single-line v3
constraints and adds the generator to `dev_dependencies`. It also updates
standard builder configuration in that package's `build.yaml`, including
target and global options, explicit builder imports, and builder ordering
and application lists. Existing comments and quotes are preserved.

Review any package the script marks for manual editing. Keep intentional
path, Git and override sources and point them at compatible v4 checkouts
yourself. For custom constraints or inline dependency maps, edit the two
dependencies directly. Packages using the builder only through a wrapper
should also check its settings. The builder key is now
`router_builder_generator:generate_route_info_helper` and the builder import
in YAML is `package:router_builder_generator/builder.dart`.

### Migrating Dart imports and exports

Run `flutter pub get` after updating the manifest. If your tooling imports or
re-exports `package:router_builder/builder.dart`, preview and apply the Dart
URI migration from the consuming package.

```bash
dart fix --dry-run
dart fix --apply
```

The old runtime library contains a deprecation marker. The generator supplies
the fix that points an import or export at
`package:router_builder_generator/builder.dart`. The builder factory
`generateRouteInfoHelperBuilder` and exception `RouterBuilderError` retain
their names. The fix was verified with Dart 3.14.0 on ordinary, prefixed and
`show` imports and a re-export. You can also replace the old URI directly.
Route annotations and models still come from
`package:router_builder/router_builder.dart`.

### Regenerating and verifying

```bash
dart run build_runner build
flutter analyze
flutter test
```

Review the regenerated `lib/routes.g.dart` with the dependency and import
changes. The resolved `dart_style` version may change line breaks.

### SDK compatibility

Check the generator's Dart SDK constraint and the analyzer range supported by
your Flutter SDK. For example, Flutter 3.44's `meta` pin allows analyzer
13.0.0. Applications that use only the v4 runtime do not resolve the generator
or its analyzer dependency.

### Quick reference (v3 -> v4)

| v3 | v4 |
| --- | --- |
| `dependencies: router_builder` (pulls analyzer) | `dependencies: router_builder` (runtime only) |
| generator bundled in `router_builder` | `dev_dependencies: router_builder_generator` |
| `package:router_builder/builder.dart` | `package:router_builder_generator/builder.dart` |
| `router_builder:generate_route_info_helper` | `router_builder_generator:generate_route_info_helper` |
| `analyzer >=9.0.0 <13.0.0` | `analyzer >=13.0.0 <15.0.0` |
| `source_gen` dependency | removed (was unused) |
| `import 'package:router_builder/router_builder.dart';` | unchanged |

---

## v2 -> v3

v3 makes one idea central: **all cascading route behavior lives in a single
`RoutePolicy`.** The flat behavioral parameters and getters that v2 carried on
`RouteInfo` and `RouteArgs` are gone; you set behavior through `policy:` and read
it back through resolved getters that are always non-null.

### What changed

- **One `RoutePolicy` (9 fields).** `mustBeAuthorized`, `duplicateBehavior`,
  `pushGlobally`, `isPopupRoute`, `visibleNavBar`, `isTopLevelOnly`,
  `shouldReplaceAll`, `deepLinkAllowed`, `deepLinkPushGlobally`. Resolution folds
  `args.policy` over `route.policy` over `RouterBuilderConfig.defaults`, then
  applies branch/redirect structural constraints last.
- **`isGlobalOnly` is now `pushGlobally`** everywhere.
- **`RouteArgs` has one constructor** (the private clone is gone) and **`isIdSlug`
  is removed**. Detect a slug-vs-id from the value at the gate.
- **Encapsulated layout.** Import only
  `package:router_builder/router_builder.dart`. Deep imports
  (`package:router_builder/models/...`) and `models/models.dart` no longer exist.
- **Generator entrypoint and output changed.** `build.yaml` imports
  `package:router_builder/builder.dart`; generated output defaults to
  `lib/routes.g.dart` with classes `Routes` and `RoutesHelper` (was
  `lib/route_info_helper.dart`, `MyRoutes`, `RouteInfoHelper`). You can pin the
  old names/path with builder options.
- **Deep-link host matching is exact-or-suffix** (was substring). `myapp.com`
  now matches `myapp.com` and `*.myapp.com`, but not `evil-myapp.com`.
- **Deep-link key conflicts fail the build** by default (`fail_on_conflict`).
- **Builder typedefs unified** to `(BuildContext, RouteArgs?)`.
- **`RouterBuilderConfig.defaults` is read-only**; configure with
  `setDefaults(RoutePolicy)` or `@RTConfig` + `RoutesHelper.installDefaults()`.

### Step 0: bump the dependency

```yaml
dependencies:
  router_builder: ^3.0.0
```

```bash
flutter pub get
```

### Step 1: run the automated codemods

A script applies the mechanical, low-risk replacements so you can focus on the
parts that need thought. Copy `tool/migrate_to_v3.sh` from the `router_builder`
repository into your app (or run it straight from your pub cache), then, from
your app root:

```bash
# DRY-RUN (default): prints a diff, edits nothing
tool/migrate_to_v3.sh lib

# apply once you have reviewed the diff
tool/migrate_to_v3.sh --write lib
```

Run it on a clean git tree so the diff is easy to review. It is idempotent.

It applies only the changes that are always safe:

- removes `isIdSlug: true|false` (the field/param is gone)
- `MyRoutes` -> `Routes`
- `RouteInfoHelper` -> `RoutesHelper`
- `route_info_helper.dart` -> `routes.g.dart` (in imports)
- deep `router_builder` imports -> the single barrel
  `package:router_builder/router_builder.dart` (and collapses the duplicate
  barrel imports that produces)

It does **not** touch anything that needs judgement. Those are the manual steps
below, and your code will not compile until you do them.

### Step 2: manual changes

#### 2a. Flat behavioral params -> `policy:`

This is the big one. Move every flat behavioral argument into a `RoutePolicy`.

**`RouteInfo` (v2 flat param -> v3 `RoutePolicy` field):**

| v2 flat param on `RouteInfo` | v3 |
|------------------------------|----|
| `isGlobalOnly`     | `policy: RoutePolicy(pushGlobally: ...)` |
| `mustBeAuthorized` | `policy: RoutePolicy(mustBeAuthorized: ...)` |
| `visibleNavBar`    | `policy: RoutePolicy(visibleNavBar: ...)` |
| `isPopupRoute`     | `policy: RoutePolicy(isPopupRoute: ...)` |
| `shouldReplaceAll` | `policy: RoutePolicy(shouldReplaceAll: ...)` |
| `isTopLevelOnly`   | `policy: RoutePolicy(isTopLevelOnly: ...)` |
| `duplicateBehavior`| `policy: RoutePolicy(duplicateBehavior: ...)` |
| `deepLinkAllowed`  | `policy: RoutePolicy(deepLinkAllowed: ...)` |

**`RouteArgs` (v2 flat param -> v3 `RoutePolicy` field):**

| v2 flat param on `RouteArgs` | v3 |
|------------------------------|----|
| `pushGlobally`     | `policy: RoutePolicy(pushGlobally: ...)` |
| `mustBeAuthorized` | `policy: RoutePolicy(mustBeAuthorized: ...)` |
| `duplicateBehavior`| `policy: RoutePolicy(duplicateBehavior: ...)` |
| `isIdSlug`         | removed (detect from the value - see 2c) |

Before:

```dart
@RT()
static const admin = RouteInfo(
  'admin',
  child: AdminPanel(),
  isGlobalOnly: true,
  mustBeAuthorized: true,
  isTopLevelOnly: true,
);

RouteArgs(Routes.login, pushGlobally: true, mustBeAuthorized: false);
```

After:

```dart
@RT()
static const admin = RouteInfo(
  'admin',
  child: AdminPanel(),
  policy: RoutePolicy(
    pushGlobally: true,
    mustBeAuthorized: true,
    isTopLevelOnly: true,
  ),
);

RouteArgs(
  Routes.login,
  policy: const RoutePolicy(pushGlobally: true, mustBeAuthorized: false),
);
```

Common shapes have presets: `RoutePolicy.global` (`pushGlobally: true`),
`RoutePolicy.public` (`mustBeAuthorized: false`), `RoutePolicy.popup`
(`isPopupRoute: true`).

#### 2b. Read-site getters

v2 behavioral getters were often nullable; v3 resolved getters are non-null, so
drop the `?? default` and rename `isGlobalOnly`:

| v2 read | v3 read |
|---------|---------|
| `route.isGlobalOnly ?? false` | `route.pushGlobally` |
| `route.mustBeAuthorized ?? true` | `route.mustBeAuthorized` |
| `route.duplicateBehavior ?? DuplicateRouteBehavior.duplicate` | `route.duplicateBehavior` |
| `(route.isGlobalOnly ?? false) \|\| args.effectivePushGlobally` | `args.effectivePushGlobally` |

`RouteArgs` keeps its `effectiveX` getters (`effectivePushGlobally`,
`effectiveMustBeAuthorized`, `effectiveIsPopupRoute`,
`effectiveDuplicateBehavior`, and the rest), now backed by the merged policy.

#### 2c. `isIdSlug` is gone

There is no flag any more. Decide at the gate from the value itself:

```dart
final raw = args.id;
final isNumericId = int.tryParse(raw ?? '') != null;
// or carry an explicit field on a RouteArgs subclass if you need to remember it
```

#### 2d. Global defaults

`RouterBuilderConfig.setDefaults(...)` no longer takes named params. Pass a
`RoutePolicy`, or declare an `@RTConfig` and install it:

```dart
// Option A: imperative
RouterBuilderConfig.setDefaults(
  const RoutePolicy(mustBeAuthorized: false, deepLinkAllowed: true),
);

// Option B: declarative (preferred) - exactly one per package
@RTConfig()
const appRoutePolicy = RoutePolicy(mustBeAuthorized: false, deepLinkAllowed: true);

void main() {
  RoutesHelper.installDefaults(); // applies appRoutePolicy as global defaults
  runApp(const MyApp());
}
```

#### 2e. `RouteArgs` subclasses

If you subclassed `RouteArgs` and forwarded flat behavioral params via
`super.*`, forward `super.policy` instead:

```dart
// v2
class DialogArgs extends RouteArgs {
  const DialogArgs(super.route, {super.pushGlobally});
}

// v3
class DialogArgs extends RouteArgs {
  const DialogArgs(super.route, {super.policy});
}
```

#### 2f. `build.yaml`

```yaml
builders:
  generate_route_info_helper:
    import: "package:router_builder/builder.dart"   # was the generator path
    builder_factories: [ "generateRouteInfoHelperBuilder" ]
    build_extensions: { r'$package$': [ "lib/routes.g.dart" ] }
    auto_apply: dependents
    build_to: source
```

To keep the old names/path instead of renaming call sites, set builder options
(`route_class_name`, `helper_class_name`, `output`). If you change `output`,
change `build_extensions` to the same path.

#### 2g. Deep links

- **Allowed hosts:** matching is now exact-or-suffix. Audit your allowed-hosts
  list; a host that only worked because of v2 substring matching will now be
  rejected.
- **Key conflicts fail the build.** If two routes share a deep-link key (name,
  first path segment, or a `deepLinkNames` alias), the build now errors. Rename
  the route, change its path, or adjust `deepLinkNames`. To downgrade to a
  warning, set the builder option `fail_on_conflict: false`.

### Step 3: regenerate

```bash
dart run build_runner build
```

(Current build_runner deletes conflicting outputs automatically; on older
build_runner versions add `--delete-conflicting-outputs`.)

### Step 4: verify

```bash
dart analyze   # or: flutter analyze
```

Fix any remaining flat-param call sites the analyzer flags (those are the manual
2a/2b changes the script intentionally left for you).

### Quick reference (v2 -> v3)

| v2 | v3 |
|----|----|
| `RouteInfo('x', mustBeAuthorized: false, isGlobalOnly: true)` | `RouteInfo('x', policy: RoutePolicy(mustBeAuthorized: false, pushGlobally: true))` |
| `RouteArgs(r, pushGlobally: true, duplicateBehavior: ...)` | `RouteArgs(r, policy: RoutePolicy(pushGlobally: true, duplicateBehavior: ...))` |
| `route.isGlobalOnly ?? false` | `route.pushGlobally` |
| `RouteArgs(..., isIdSlug: true)` | detect via `int.tryParse(args.id ?? '')`, or a `RouteArgs` subclass field |
| `DialogArgs(... super.pushGlobally ...)` | `DialogArgs(... super.policy ...)` |
| `import 'package:router_builder/models/models.dart'` | `import 'package:router_builder/router_builder.dart'` |
| `import 'route_info_helper.dart'`; `MyRoutes.x` / `RouteInfoHelper` | `import 'routes.g.dart'`; `Routes.x` / `RoutesHelper` (or pin old names via builder options) |
| build.yaml imports the generator path | imports `package:router_builder/builder.dart` |
| deep-link allowed hosts (substring match) | exact-or-suffix; verify the list |
| `RouterBuilderConfig.setDefaults(mustBeAuthorized: false)` | `setDefaults(const RoutePolicy(mustBeAuthorized: false))`, or `@RTConfig` + `RoutesHelper.installDefaults()` |

---

## Appendix: v0.x -> v1.0 (unified deep links) - historical

v1.0 replaced the separate `DeepLinkRegistry` (RegExp patterns registered in an
`action_registry.dart`) with deep links defined directly on the route. Routes
became the single source of truth.

Before: a route plus a separate `DeepLinkHandler` subclass with a `RegExp`
pattern, registered globally.

After: declare the path and aliases on the route, and only add a
`deepLinkHandler` for genuinely custom logic:

```dart
@RT()
static final product = RouteInfo(
  'product',
  path: 'product/:id',
  deepLinkNames: ['item', 'p'], // optional aliases
  builder: _builder,
);
```

For complex cases, attach a handler and read params off the URI:

```dart
@RT()
static final referral = RouteInfo(
  'referral',
  path: 'referral/:code',
  deepLinkHandler: const ReferralDeepLinkHandler(),
  builder: _builder,
);

class ReferralDeepLinkHandler extends DeepLinkHandler<MyAction> {
  const ReferralDeepLinkHandler();

  @override
  bool canHandle(Uri uri) => true;

  @override
  MyAction? createAction(Uri uri, RouteInfo route) =>
      SaveReferralCodeAction(code: uri.pathSegments.last);
}
```

Cleanup after migrating to v1.0: delete the old registry, the RegExp handler
implementations, their registrations, and any `toDeepLinkAction()` URI
extension. Path params (`:id`) and conflict detection are handled for you at
build time.

> If you are coming from v0.x, do the v1.0 migration first, then follow the
> [v2 -> v3](#v2---v3) section above. (The v1.0-era examples used the old
> `RouteInfoHelper` / `route_info_helper.dart` names; v3 renamed those to
> `RoutesHelper` / `routes.g.dart`.)

---

## Template for future migrations

When cutting the next major version, prepend a section in this shape:

```markdown
## vN-1 -> vN

### What changed
- Bullet the breaking changes, each with the old -> new in one line.

### Step 0: bump the dependency
The pubspec change + `flutter pub get`.

### Step 1: run the automated codemods
Point at `tool/migrate_to_vN.sh` (dry-run by default, `--write` to apply).
List exactly what it rewrites - only the mechanical, always-safe changes.

### Step 2: manual changes
The changes that need judgement, with before/after for each. Be explicit that
the script does not touch these and the code will not compile until they are done.

### Step 3: regenerate
`dart run build_runner build` (if codegen changed).

### Step 4: verify
`dart analyze` / `flutter analyze`, and run the tests.

### Quick reference (vN-1 -> vN)
A compact old -> new table.
```

Keep each `tool/migrate_to_vN.sh` focused on the safe, mechanical edits
(renames, removed flags, import moves). Leave structural rewrites to the manual
steps - a wrong automated edit is worse than a documented manual one.

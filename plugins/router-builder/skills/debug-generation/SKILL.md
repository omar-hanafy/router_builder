---
name: debug-generation
description: Use when router_builder code generation misbehaves - routes.g.dart missing, stale, or not updating, build_runner failing with RouterBuilderError (deep-link key conflicts, @RTConfig errors, branch enum mismatch), @RT routes not discovered, dependency solve failures around analyzer/build/source_gen/dart_style when adding or upgrading router_builder, or customizing builder options (output path, class names, fail_on_conflict).
---

# Debug router_builder code generation

The generator is deterministic: it scans `lib/**.dart` for `@RT`/`@RTConfig`
and writes one file. Failures are declaration errors, discovery misses, stale
caches, or dependency conflicts - in that order of likelihood. Exact rules,
options, error catalog, and the troubleshooting sequence are in
[references/generator-reference.md](references/generator-reference.md).

## Workflow

1. Run `dart run build_runner build` and read the FULL error output.
   `RouterBuilderError` messages name the offending declarations; match them
   against the catalog in the reference and fix the DECLARATION (conflicting
   keys, duplicate/non-const `@RTConfig`, mixed branch enums). Do not reach for
   `fail_on_conflict: false` or generator option changes to silence a
   declaration error.
2. No error but wrong/missing output: check discovery rules (public static
   class fields + public top-level const/final in `lib/` only), then
   `dart run build_runner clean` and rebuild; then check for a consumer
   `build.yaml` overriding `output`.
3. Dependency solve failures mentioning analyzer/build/source_gen/dart_style:
   identify the pinning package from the solver output (`dart pub deps` helps),
   upgrade it; router_builder 3.0.1 accepts `analyzer >=9.0.0 <13.0.0`. Use
   `dependency_overrides` only as a diagnostic, never a committed fix. If the
   project is still on router_builder 2.x, 2.0.3/2.0.4 exist specifically to
   relax these ranges.
4. Customization requests (rename generated classes, move the output, keep
   v2-era names): use the builder options block from the reference, and keep
   any `build_extensions` redefinition consistent with `output`.
5. Verify: regenerate, `dart analyze`, and confirm the generated surface
   (route present in `Routes`, expected `deepLinkMap` keys). Never hand-edit
   `routes.g.dart`.

## Maintainer note (the package repo itself)

Inside the router_builder REPO, model tests run with `flutter test` while
generator tests are tagged and need `dart test --run-skipped test/generator/`;
"generator tests are skipped" there is configuration, not a bug.

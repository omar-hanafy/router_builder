/// Build entrypoint for router_builder's code generator.
///
/// Referenced by `build.yaml` as
/// `package:router_builder_generator/builder.dart`; the build_runner
/// convention is for a package's builder factories to live here.
///
/// Apps that run the builder add this package to `dev_dependencies`.
/// A package that imports or re-exports the builder from its published
/// `lib/` declares it in `dependencies` so downstream packages can resolve it.
library;

export 'router_builder_generator.dart';

/// Build entrypoint for router_builder's code generator.
///
/// Referenced by `build.yaml` as
/// `package:router_builder_generator/builder.dart`; the build_runner
/// convention is for a package's builder factories to live here.
///
/// This package is build-time only: add it to `dev_dependencies`, never to
/// `dependencies`, so that `analyzer`, `build`, and `dart_style` stay out of an
/// app's production dependency graph.
library;

export 'router_builder_generator.dart';

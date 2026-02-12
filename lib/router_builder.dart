/// Public package entry point that re-exports the router builder toolchain.
///
/// Import this library to access annotations, models, deep link helpers, and
/// handlers required to define routes and generate supporting code.
library;

export 'annotations/route.dart';
export 'deeplink/deep_link_matcher.dart';
export 'handlers/deep_link_handler.dart';
export 'models/route_args.dart';
export 'models/route_info.dart';
export 'models/route_policy.dart';
export 'router_config.dart';

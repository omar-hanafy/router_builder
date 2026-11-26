/// Public entry point for router_builder: annotations, models, config, the
/// deep-link layer, and handlers. Import this library to define routes and use
/// the generated helper. Custom builders can import `package:router_builder_generator/builder.dart`.
library;

export 'src/annotations/route.dart';
export 'src/deeplink/deep_link_matcher.dart';
export 'src/handlers/deep_link_handler.dart';
export 'src/models/duplicate_route_behavior.dart';
export 'src/models/route_args.dart';
export 'src/models/route_info.dart';
export 'src/models/route_policy.dart';
export 'src/router_config.dart';

/// Build entrypoint for router_builder's code generator.
///
/// Referenced by `build.yaml`. Kept separate from the runtime barrel so the
/// generator's heavy dependencies (analyzer, build, dart_style) never reach
/// consumer apps.
library;

export 'src/generators/generate_route_info_helper.dart'
    show generateRouteInfoHelperBuilder, RouterBuilderError;

/// Public API of router_builder's code generator.
///
/// Most users never import this: `build_runner` reaches the builder through
/// `build.yaml`, which points at `builder.dart`. Import this library only to
/// construct or wrap the builder yourself.
library;

export 'src/generate_route_info_helper.dart'
    show RouterBuilderError, generateRouteInfoHelperBuilder;

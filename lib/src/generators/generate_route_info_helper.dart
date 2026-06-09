import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
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
          out.configs.add(
            _configRef('$className.$fieldName', importUri, field),
          );
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
    final init = (node is VariableDeclaration) ? node.initializer : null;
    final creation = init is InstanceCreationExpression ? init : null;
    final ctorName = creation?.constructorName.name?.name;
    final kind =
        ctorName == 'branch'
            ? 'branch'
            : ctorName == 'redirect'
            ? 'redirect'
            : 'standard';

    final value = element.computeConstantValue();

    final data = <String, Object?>{
      'ref': ref,
      'importUri': importUri.toString(),
      'routeName':
          value?.getField('name')?.toStringValue() ??
          _positionalString(creation),
      'path':
          value?.getField('_path')?.toStringValue() ??
          _namedString(creation, 'path'),
      'deepLinkNames': _stringList(value, 'deepLinkNames', creation),
      'kind': kind,
      'branchParentType': null,
      'branchParentType_type': null,
      'branchParentType_import': null,
      'branchIndex':
          value?.getField('branchIndex')?.toIntValue() ??
          _namedInt(creation, 'branchIndex'),
      'branchKey':
          value?.getField('branchKey')?.toStringValue() ??
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
    final fromConst =
        value
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
    final buffer =
        StringBuffer()
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

  void _writeRoutesClass(
    StringBuffer buffer,
    List<Map<String, Object?>> routes,
  ) {
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
    final allSame = branches.every((b) => b['branchParentType_type'] == first);
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
        (a, b) => ((a['branchIndex'] as int?) ?? 0).compareTo(
          (b['branchIndex'] as int?) ?? 0,
        ),
      );
    }
    final buffer =
        StringBuffer()
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
        (a, b) => ((a['branchIndex'] as int?) ?? 0).compareTo(
          (b['branchIndex'] as int?) ?? 0,
        ),
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
    final buffer =
        StringBuffer()
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
    final enumType = _branchEnumType(
      routes.where((r) => r['kind'] == 'branch').toList(),
    );
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

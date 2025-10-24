import 'dart:async';

// External package imports
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_helper_utils/dart_helper_utils.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

/// A [Builder] that generates a `route_info_helper.dart` file containing route
/// information for fields annotated with `RT`.
///
/// This builder scans all Dart files under `lib/`, identifies static public fields
/// annotated with `RT`, extracts their route data (e.g., name, branch type),
/// and generates a helper file with utilities for accessing routes. The output
/// file, located at `lib/route_info_helper.dart`, includes the [RouteInfoHelper]
/// and [MyRoutes] classes for use in routing logic.
///
/// Intended for use in a `build.yaml` configuration, for example:
/// ```yaml
/// builders:
///   route_info_helper:
///     import: "package:my_package/builder.dart"
///     builder_factories: ["generateRouteInfoHelperBuilder"]
///     build_extensions: { "$package$": ["lib/route_info_helper.dart"] }
///     auto_apply: root_package
///     build_to: source
/// ```
class GenerateRouteInfoHelperBuilder implements Builder {
  @override
  final buildExtensions = const {
    r'$package$': ['lib/route_info_helper.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    log.info('Starting GenerateRouteInfoHelperBuilder...');

    // Gather annotated route fields across the project.
    final annotatedFields = await _collectAnnotatedFields(buildStep);

    // Format the generated Dart code and write it out.
    final formattedCode = _formatGeneratedCode(annotatedFields);
    await _writeOutputFile(buildStep, formattedCode);

    log.info('Successfully wrote route_info_helper.dart!');
  }

  // --------------------------------------------------------------------------
  // ANNOTATION DISCOVERY
  // --------------------------------------------------------------------------

  /// Collects all fields annotated with `RT` across the project and returns a list
  /// of maps containing route data.
  Future<List<Map<String, Object?>>> _collectAnnotatedFields(
    BuildStep buildStep,
  ) async {
    final annotatedFields = <Map<String, Object?>>[];

    // Search within all Dart files under 'lib'.
    final dartFiles = await buildStep.findAssets(Glob('lib/**.dart')).toList();
    for (final inputId in dartFiles) {
      if (await buildStep.resolver.isLibrary(inputId)) {
        final library = await buildStep.resolver.libraryFor(inputId);
        final fieldsFromThisLibrary = await _processLibrary(library, buildStep);
        annotatedFields.addAll(fieldsFromThisLibrary);
      } else {
        log.info('Skipping non-library file: ${inputId.path}');
      }
    }

    return annotatedFields;
  }

  /// Processes a single library to find classes and their static public fields
  /// annotated with `RT`, and returns a list of route data maps.
  Future<List<Map<String, Object?>>> _processLibrary(
    LibraryElement library,
    BuildStep buildStep,
  ) async {
    final annotatedFields = <Map<String, Object?>>[];

    for (final classElement in library.classes) {
      for (final field in classElement.fields) {
        if (field.isStatic && field.isPublic) {
          final routeAnnotation = _getRouteAnnotation(field);
          if (routeAnnotation != null) {
            final routeData = await _extractRouteData(
              field,
              classElement,
              buildStep,
            );
            annotatedFields.add(routeData);
          }
        }
      }
    }

    return annotatedFields;
  }

  /// Retrieves the `RT` annotation from a field's metadata if present, or returns null.
  DartObject? _getRouteAnnotation(FieldElement field) {
    for (final annotation in field.metadata.annotations) {
      final element = annotation.element;
      if (element is ConstructorElement) {
        final enclosingElement = element.enclosingElement;
        if (enclosingElement.name == 'RT') {
          return annotation.computeConstantValue();
        }
      }
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // ROUTE DATA EXTRACTION
  // --------------------------------------------------------------------------

  /// Extracts route data from an annotated field, including the import URI and
  /// default properties from `RouteInfo`.
  Future<Map<String, Object?>> _extractRouteData(
    FieldElement field,
    ClassElement classElement,
    BuildStep buildStep,
  ) async {
    final importUri = await _getImportUri(classElement, buildStep);

    final data = {
      'className': classElement.name,
      'fieldName': field.name,
      'importUri': importUri.toString(),
      'isBranch': false,
      'isGlobalOnly': false,
      'forRedirectionOnly': false,
      'branchIndex': null,
      'branchParentType': null,
      'branchParentType_type': null, // Enum type name
      'branchParentType_import': null, // Enum import URI
      'branchKey': null,
      'routeName': null,
      'isConst': field.isConst,
      'deepLinkAllowed': true,
      'mustBeAuthorized': true,
      'visibleNavBar': true,
      'isPopupRoute': false,
      'isTopLevelOnly': false,
      'replaceAll': false,
      'deepLinkNames': const <String>[],
      'path': null,
      'hasDeepLinkHandler': false,
    };

    await _enrichRouteDataFromNode(data, field, buildStep);

    log.info('Extracted route data: $data');
    return data;
  }

  /// Parses the AST node of a field to determine its constructor type and enriches
  /// the route data with initializer arguments.
  Future<void> _enrichRouteDataFromNode(
    Map<String, Object?> data,
    FieldElement field,
    BuildStep buildStep,
  ) async {
    final fieldNode = await buildStep.resolver.astNodeFor(
      field.firstFragment,
      resolve: true,
    );
    if (fieldNode is VariableDeclaration) {
      final initializer = fieldNode.initializer;
      if (initializer is InstanceCreationExpression) {
        final constructorName = initializer.constructorName.name?.name;
        if (constructorName == 'branch') {
          data['isBranch'] = true;
        } else if (constructorName == 'redirect') {
          data['forRedirectionOnly'] = true;
        }
        _processInitializerArguments(data, initializer.argumentList.arguments);
      }
    } else {
      log.warning('Field node is not a VariableDeclaration for ${field.name}');
    }
  }

  /// Processes initializer arguments, extracting the positional route name and named arguments.
  void _processInitializerArguments(
    Map<String, Object?> data,
    List<Expression> args,
  ) {
    if (args.isNotEmpty) {
      final firstArg = args.first;
      if (firstArg is StringLiteral) {
        data['routeName'] = firstArg.stringValue;
      }
    }

    for (final arg in args) {
      if (arg is NamedExpression) {
        _processNamedArgument(data, arg);
      }
    }
  }

  /// Assigns values from named arguments to the route data map, handling enums for
  /// `branchParentType` specifically.
  void _processNamedArgument(Map<String, Object?> data, NamedExpression arg) {
    final name = arg.name.label.name;
    final expression = arg.expression;

    switch (name) {
      case 'isGlobalOnly':
        if (expression is BooleanLiteral) {
          data['isGlobalOnly'] = expression.value;
        }
      case 'branchIndex':
        if (expression is IntegerLiteral) {
          data['branchIndex'] = expression.value;
        }
      case 'branchParentType':
        data['branchParentType'] =
            expression.toSource(); // e.g., 'MyShellType.home'
        final enumType = expression.staticType;
        final enumElement = enumType?.element;
        if (enumElement is EnumElement) {
          data['branchParentType_type'] =
              enumElement.name; // e.g., 'MyShellType'
          final enumLibrary = enumElement.library;
          final importUri = enumLibrary.uri.toString();
          data['branchParentType_import'] =
              importUri; // e.g., 'package:my_app/shell.dart'
        } else {
          log.warning(
            'branchParentType for ${data['fieldName']} is not an enum value.',
          );
        }
      case 'branchKey':
        if (expression is StringLiteral) {
          data['branchKey'] = expression.stringValue;
        }
      case 'deepLinkAllowed':
        if (expression is BooleanLiteral) {
          data['deepLinkAllowed'] = expression.value;
        }
      case 'mustBeAuthorized':
        if (expression is BooleanLiteral) {
          data['mustBeAuthorized'] = expression.value;
        }
      case 'visibleNavBar':
        if (expression is BooleanLiteral) {
          data['visibleNavBar'] = expression.value;
        }
      case 'isPopupRoute':
        if (expression is BooleanLiteral) {
          data['isPopupRoute'] = expression.value;
        }
      case 'replaceAll':
        if (expression is BooleanLiteral) {
          data['replaceAll'] = expression.value;
        }
      case 'isTopLevelOnly':
        if (expression is BooleanLiteral) {
          data['isTopLevelOnly'] = expression.value;
        }
      case 'deepLinkNames':
        if (expression is ListLiteral) {
          final names =
              expression.elements
                  .whereType<StringLiteral>()
                  .map((e) => e.stringValue)
                  .whereType<String>()
                  .toList();
          data['deepLinkNames'] = names;
        }
      case 'path':
        if (expression is StringLiteral) {
          data['path'] = expression.stringValue;
        }
      case 'deepLinkHandler':
        // Just mark that it has a handler, we can't serialize the instance
        data['hasDeepLinkHandler'] = true;
    }
  }

  // --------------------------------------------------------------------------
  // FILE WRITING
  // --------------------------------------------------------------------------

  /// Resolves the import URI for a class element's library.
  Future<Uri> _getImportUri(
    ClassElement classElement,
    BuildStep buildStep,
  ) async {
    final library = classElement.library;
    final assetId = await buildStep.resolver.assetIdForElement(library);
    return assetId.uri;
  }

  /// Formats the generated Dart code using DartFormatter for consistency.
  String _formatGeneratedCode(List<Map<String, Object?>> fields) {
    final code = _generateRouteInfoHelperCode(fields);
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    return formatter.format(code);
  }

  /// Writes the formatted code to `lib/route_info_helper.dart`.
  Future<void> _writeOutputFile(
    BuildStep buildStep,
    String formattedCode,
  ) async {
    final outputId = AssetId(
      buildStep.inputId.package,
      'lib/route_info_helper.dart',
    );
    log.info('Writing output to ${outputId.path}...');
    await buildStep.writeAsString(outputId, formattedCode);
  }

  // --------------------------------------------------------------------------
  // CODE GENERATION
  // --------------------------------------------------------------------------

  /// Generates the complete source code for `route_info_helper.dart`, including
  /// a header comment and the definitions of [RouteInfoHelper] and [MyRoutes].
  String _generateRouteInfoHelperCode(List<Map<String, Object?>> fields) {
    final buffer =
        StringBuffer()
          // Generated file header
          ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
          ..writeln('//')
          ..writeln(
            '// This file is generated by the GenerateRouteInfoHelperBuilder.',
          )
          ..writeln('// To update it, run:')
          ..writeln('//   flutter pub run build_runner build')
          ..writeln();

    _writeImports(buffer, fields);
    _writeRouteInfoHelperClass(buffer, fields);
    _writeMyRoutesClass(buffer, fields);
    return buffer.toString();
  }

  /// Writes import statements to the buffer.
  void _writeImports(StringBuffer buffer, List<Map<String, Object?>> fields) {
    final importUris =
        fields.map((f) => f.getString('importUri')).toSet()..addAll([
          'package:dart_helper_utils/dart_helper_utils.dart',
          'package:router_builder/router_builder.dart',
          'package:router_builder/deeplink/deep_link_matcher.dart',
        ]);

    for (final field in fields) {
      final bpImport = field['branchParentType_import'];
      if (bpImport is String && bpImport.isNotEmpty) {
        importUris.add(bpImport);
      }
    }

    final sortedUris = importUris.toList()..sort();
    for (final uri in sortedUris) {
      buffer.writeln("import '$uri';");
    }
    buffer.writeln();
  }

  /// Writes the definition of the [RouteInfoHelper] class to the buffer.
  void _writeRouteInfoHelperClass(
    StringBuffer buffer,
    List<Map<String, Object?>> fields,
  ) {
    buffer
      ..writeln(
        '/// A helper class providing access to route information and utilities.',
      )
      ..writeln('///')
      ..writeln(
        '/// Use this class to access categorized routes (e.g., branches, global routes)',
      )
      ..writeln('/// and utility methods for route lookups.')
      ..writeln('abstract class RouteInfoHelper {')
      ..writeln('  // Branch-related members')
      ..writeln(_generateBranchesMap(fields))
      ..writeln()
      ..writeln('  // Static lists for branches by enum value')
      ..writeln(_generateEnumValueBranchLists(fields))
      ..writeln()
      ..writeln('  // Other route categories')
      ..writeln(_generateNormalRoutesList(fields))
      ..writeln()
      ..writeln(_generateGlobalRoutesList(fields))
      ..writeln()
      ..writeln(_generatePopupRoutesList(fields))
      ..writeln()
      ..writeln(_generateTopLevelRoutesList(fields))
      ..writeln()
      ..writeln(_generateAuthorizedRoutesList(fields))
      ..writeln()
      ..writeln(_generateDeepLinkMap(fields))
      ..writeln()
      ..writeln(_generateAllRoutesList())
      ..writeln()
      ..writeln('  // Helper methods')
      ..writeln(_generateFromNameMethod())
      ..writeln(_generateDeepLinkHelpers())
      ..writeln(_generateBranchesHelpers(fields))
      ..writeln('}')
      ..writeln();
  }

  /// Generates a map of branch routes grouped by enum value.
  String _generateBranchesMap(List<Map<String, Object?>> fields) {
    final branchFields = fields.where((f) => f['isBranch'] == true).toList();
    var enumTypeName = 'Enum';
    if (branchFields.isNotEmpty) {
      final firstEnumType =
          branchFields.first['branchParentType_type'] as String?;
      if (firstEnumType != null) {
        final allSame = branchFields.every(
          (f) => f['branchParentType_type'] == firstEnumType,
        );
        if (allSame) {
          enumTypeName = firstEnumType;
        } else {
          log.severe(
            'All branch routes must use the same enum type for branchParentType.',
          );
        }
      }
    }

    final grouped = <String, List<Map<String, Object?>>>{};
    for (final field in branchFields) {
      final parentID = field['branchParentType'] as String?;
      if (parentID != null) {
        grouped.putIfAbsent(parentID, () => []).add(field);
      }
    }

    // Sort each group by branchIndex
    for (final group in grouped.values) {
      group.sort((a, b) {
        final aIndex = a['branchIndex'] as int?;
        final bIndex = b['branchIndex'] as int?;
        if (aIndex == null && bIndex == null) return 0;
        if (aIndex == null) return 1;
        if (bIndex == null) return -1;
        return aIndex.compareTo(bIndex);
      });
    }

    final buffer =
        StringBuffer()
          ..writeln(
            '  /// Map of enum values to their corresponding branch routes.',
          )
          ..writeln('  ///')
          ..writeln(
            '  /// All branch routes must use the enum type `$enumTypeName`.',
          )
          ..writeln(
            '  static final Map<$enumTypeName, Map<int?, RouteInfo>> branches = {',
          );
    grouped.forEach((parentID, list) {
      buffer
        ..writeln('    $parentID: {')
        ..writeAll(
          list.map(
            (field) =>
                '      ${field['className']}.${field['fieldName']}.branchIndex: ${field['className']}.${field['fieldName']},',
          ),
          '\n',
        )
        ..writeln('    },');
    });
    buffer.writeln('  };');
    return buffer.toString();
  }

  /// Generates static lists for each enum value's branches, e.g., `homeBranches`.
  String _generateEnumValueBranchLists(List<Map<String, Object?>> fields) {
    final branchFields = fields.where((f) => f['isBranch'] == true).toList();
    if (branchFields.isEmpty) return ''; // No branches, skip generation

    // Verify consistent enum type across all branches
    final firstEnumType =
        branchFields.first['branchParentType_type'] as String?;
    if (firstEnumType != null) {
      final allSame = branchFields.every(
        (f) => f['branchParentType_type'] == firstEnumType,
      );
      if (!allSame) {
        log.severe(
          'Inconsistent enum types detected; skipping enum value lists.',
        );
        return '';
      }
    }

    // Group branches by enum value
    final enumValuesMap = <String, List<Map<String, Object?>>>{};
    for (final field in branchFields) {
      final parentID = field['branchParentType'] as String?;
      if (parentID != null) {
        enumValuesMap.putIfAbsent(parentID, () => []).add(field);
      }
    }

    // Sort each group by branchIndex
    for (final routes in enumValuesMap.values) {
      routes.sort((a, b) {
        final aIndex = a['branchIndex'] as int?;
        final bIndex = b['branchIndex'] as int?;
        if (aIndex == null && bIndex == null) return 0;
        if (aIndex == null) return 1;
        if (bIndex == null) return -1;
        return aIndex.compareTo(bIndex);
      });
    }

    final buffer = StringBuffer();
    enumValuesMap.forEach((enumValue, routes) {
      // Extract the enum value name (e.g., 'home' from 'MyShellType.home')
      final valueName = enumValue.split('.').last;
      final listName = '${valueName}Branches';

      buffer
        ..writeln('  /// Branches for `$enumValue`.')
        ..writeln('  static final List<RouteInfo> $listName = [')
        ..writeAll(
          routes.map(
            (field) => '    ${field['className']}.${field['fieldName']},',
          ),
          '\n',
        )
        ..writeln('  ];')
        ..writeln();
    });

    return buffer.toString().trimRight();
  }

  /// Generates a list of normal routes (non-branch, non-global, non-redirection).
  String _generateNormalRoutesList(List<Map<String, Object?>> fields) {
    final buffer =
        StringBuffer()
          ..writeln(
            '  /// List of normal routes (non-branch, non-global, non-redirection).',
          )
          ..writeln('  static final List<RouteInfo> normalRoutes = [');
    for (final field in fields) {
      if (field['isBranch'] != true &&
          field['isGlobalOnly'] != true &&
          field['forRedirectionOnly'] != true) {
        buffer.writeln('    ${field['className']}.${field['fieldName']},');
      }
    }
    buffer.writeln('  ];');
    return buffer.toString();
  }

  /// Generates a list of global routes.
  String _generateGlobalRoutesList(List<Map<String, Object?>> fields) {
    final buffer =
        StringBuffer()
          ..writeln('  /// List of global routes.')
          ..writeln('  static final List<RouteInfo> globalRoutes = [');
    for (final field in fields) {
      if (field['isGlobalOnly'] == true &&
          field['isBranch'] != true &&
          field['forRedirectionOnly'] != true) {
        buffer.writeln('    ${field['className']}.${field['fieldName']},');
      }
    }
    buffer.writeln('  ];');
    return buffer.toString();
  }

  /// Generates a list of popup routes.
  String _generatePopupRoutesList(List<Map<String, Object?>> fields) {
    final buffer =
        StringBuffer()
          ..writeln('  /// List of popup routes.')
          ..writeln('  static final List<RouteInfo> popupRoutes = [');
    for (final field in fields) {
      if (field['isPopupRoute'] == true) {
        buffer.writeln('    ${field['className']}.${field['fieldName']},');
      }
    }
    buffer.writeln('  ];');
    return buffer.toString();
  }

  /// Generates a list of top-level-only routes.
  String _generateTopLevelRoutesList(List<Map<String, Object?>> fields) {
    final buffer =
        StringBuffer()
          ..writeln('  /// List of top-level-only routes.')
          ..writeln('  static final List<RouteInfo> topLevelRoutes = [');
    for (final field in fields) {
      if (field['isTopLevelOnly'] == true) {
        buffer.writeln('    ${field['className']}.${field['fieldName']},');
      }
    }
    buffer.writeln('  ];');
    return buffer.toString();
  }

  /// Generates a list of routes that require authorization.
  String _generateAuthorizedRoutesList(List<Map<String, Object?>> fields) {
    final buffer =
        StringBuffer()
          ..writeln('  /// List of routes that require authorization.')
          ..writeln('  static final List<RouteInfo> authorizedRoutes = [');
    for (final field in fields) {
      if (field['mustBeAuthorized'] == true) {
        buffer.writeln('    ${field['className']}.${field['fieldName']},');
      }
    }
    buffer.writeln('  ];');
    return buffer.toString();
  }

  /// Generates a comprehensive map for deep link and route resolution with conflict detection.
  String _generateDeepLinkMap(List<Map<String, Object?>> fields) {
    final buffer = StringBuffer();
    final deepLinkMap = <String, String>{}; // key -> "Class.field"
    final conflicts = <String, List<String>>{}; // key -> [sources]

    // Build map and detect conflicts
    for (final field in fields) {
      if (field['deepLinkAllowed'] == false) {
        continue;
      }
      if (field['forRedirectionOnly'] == true) {
        continue;
      }

      final routeReference = "${field['className']}.${field['fieldName']}";
      final keysToAdd = _extractAllRouteKeys(field);

      for (final key in keysToAdd) {
        if (deepLinkMap.containsKey(key)) {
          conflicts[key] ??= [deepLinkMap[key]!];
          conflicts[key]!.add(routeReference);
        } else {
          deepLinkMap[key] = routeReference;
        }
      }
    }

    // Report conflicts
    if (conflicts.isNotEmpty) {
      _reportConflicts(conflicts);
    }

    // Generate code with documentation
    buffer
      ..writeln('  /// Comprehensive map for deep link and route resolution.')
      ..writeln(
        '  /// Keys include: route names, path segments, and deep link aliases.',
      )
      ..writeln('  /// ')
      ..writeln(
        '  /// This map is used by the DeepLinkResolver to find routes from URIs.',
      )
      ..writeln('  static final Map<String, RouteInfo> deepLinkMap = {');

    // Sort keys for consistent output
    final sortedKeys = deepLinkMap.keys.toList()..sort();
    for (final key in sortedKeys) {
      buffer.writeln("    '$key': ${deepLinkMap[key]},");
    }

    buffer.writeln('  };');
    return buffer.toString();
  }

  /// Extracts all possible keys for a route (name, path segment, deep link names).
  Set<String> _extractAllRouteKeys(Map<String, Object?> field) {
    final keys = <String>{};
    final routeName = field['routeName'] as String?;
    final deepLinkNames = field['deepLinkNames'] as List<String>? ?? [];

    // 1. Always add route name as a key
    if (routeName != null && routeName.isNotEmpty) {
      keys.add(routeName);
    }

    // 2. Add deep link aliases (if any)
    if (deepLinkNames.isNotEmpty) {
      keys.addAll(deepLinkNames);
    }

    // 3. Path-based key (first segment) - always add if different
    final path = field['path'] as String?;
    if (path != null && path.isNotEmpty) {
      final pathKey = _extractPathKey(path);
      if (pathKey != null && !keys.contains(pathKey)) {
        keys.add(pathKey);
      }
    }

    return keys;
  }

  /// Extracts the first segment from a path as a potential key.
  String? _extractPathKey(String path) {
    // Remove leading slash if present
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Extract first segment (before any / or :)
    final match = RegExp('^([^/:]+)').firstMatch(cleanPath);
    return match?.group(1);
  }

  /// Reports deep link key conflicts to the console.
  void _reportConflicts(Map<String, List<String>> conflicts) {
    for (final entry in conflicts.entries) {
      final key = entry.key;
      final sources = entry.value;
      log.severe('''
[SEVERE] Deep Link Key Conflict Detected!
  Key: '$key'
  Used by: ${sources.join(', ')}
  
  Resolution: Each key must be unique across all routes. Please:
  1. Change the route name, OR
  2. Modify the path, OR  
  3. Update deepLinkNames to avoid this conflict.
''');
    }
  }

  /// Combines all routes into a single list.
  String _generateAllRoutesList() {
    return '''
  /// Combined list of all routes.
  static final List<RouteInfo> allRoutes = [
    ...branches.values.expand((inner) => inner.values),
    ...normalRoutes,
    ...globalRoutes,
  ];
''';
  }

  /// Generates a method to find a route by its name.
  String _generateFromNameMethod() {
    return '''
  /// Returns the [RouteInfo] for the given route name, or null if not found.
  static RouteInfo? fromName(String? name) {
    return allRoutes.firstWhereOrNull((route) => route.name == name);
  }
''';
  }

  String _generateDeepLinkHelpers() {
    return '''
  /// Resolve a deep link URI into a [RouteInfo] and [RouteArgs].
  static DeepLinkMatch? resolveDeepLink(
    Uri incoming, {
    Iterable<String> allowedHosts = const [],
  }) {
    final normalized = DeepLinkMatcher.normalizeToAppPath(
      incoming,
      hosts: allowedHosts,
    );
    return const DeepLinkMatcher().match(
      normalized,
      allRoutes,
      original: incoming,
    );
  }

  /// Normalize an incoming deep link URI to an app-internal path.
  static Uri normalizeToAppPath(
    Uri incoming, {
    Iterable<String> allowedHosts = const [],
  }) {
    return DeepLinkMatcher.normalizeToAppPath(
      incoming,
      hosts: allowedHosts,
    );
  }
''';
  }

  /// Generates helper methods for working with branch routes.
  String _generateBranchesHelpers(List<Map<String, Object?>> fields) {
    final branchFields = fields.where((f) => f['isBranch'] == true).toList();
    var enumTypeName = 'Enum';
    if (branchFields.isNotEmpty) {
      final firstEnumType =
          branchFields.first['branchParentType_type'] as String?;
      if (firstEnumType != null) {
        final allSame = branchFields.every(
          (f) => f['branchParentType_type'] == firstEnumType,
        );
        if (allSame) {
          enumTypeName = firstEnumType;
        } else {
          log.severe(
            'All branch routes must use the same enum type for branchParentType.',
          );
        }
      }
    }

    final buffer =
        StringBuffer()
          ..writeln(
            '  /// Returns the map of branch routes for the given shell enum value.',
          )
          ..writeln(
            '  static Map<int?, RouteInfo>? branchesFor($enumTypeName shell) {',
          )
          ..writeln('    return branches[shell];')
          ..writeln('  }')
          ..writeln()
          ..writeln('  /// Returns a list of all branch routes.')
          ..writeln('  static List<RouteInfo> allBranches() {')
          ..writeln(
            '    return branches.values.expand((innerMap) => innerMap.values).toList();',
          )
          ..writeln('  }')
          ..writeln()
          ..writeln(
            '  /// Returns the branch route for the given shell and index, if it exists.',
          )
          ..writeln(
            '  static RouteInfo? branchByIndex($enumTypeName shell, int? index) {',
          )
          ..writeln('    return branches[shell]?[index];')
          ..writeln('  }')
          ..writeln()
          ..writeln(
            '  /// Checks if a given route belongs to the specified shell.',
          )
          ..writeln(
            '  static bool isRouteInShell(RouteInfo route, $enumTypeName shell) {',
          )
          ..writeln(
            '    return branches[shell]?.containsValue(route) ?? false;',
          )
          ..writeln('  }')
          ..writeln()
          ..writeln('  /// Finds a branch route by its key.')
          ..writeln('  static RouteInfo? branchByKey(String key) {')
          ..writeln('    return branches.values')
          ..writeln('        .expand((innerMap) => innerMap.values)')
          ..writeln(
            '        .firstWhereOrNull((route) => route.branchKey == key);',
          )
          ..writeln('  }');
    return buffer.toString();
  }

  // --------------------------------------------------------------------------
  // GENERATED CLASS: MyRoutes
  // --------------------------------------------------------------------------

  /// Writes the definition of the [MyRoutes] class to the buffer.
  void _writeMyRoutesClass(
    StringBuffer buffer,
    List<Map<String, Object?>> fields,
  ) {
    buffer
      ..writeln(
        '/// A class providing static constants for all defined routes.',
      )
      ..writeln('abstract class MyRoutes {');
    for (final field in fields) {
      final routeName = field['routeName'] as String?;
      if (routeName == null) continue;

      final className = _safeString(field['className']);
      final fieldName = _safeString(field['fieldName']);
      final isConst = field['isConst'] == true;
      final safeVarName = _makeSafeIdentifier(routeName);

      buffer.writeln(
        '  static ${isConst ? 'const' : 'final'} RouteInfo $safeVarName = '
        '$className.$fieldName;',
      );
    }
    buffer.writeln('}');
  }

  // --------------------------------------------------------------------------
  // UTILITY METHODS
  // --------------------------------------------------------------------------

  /// Safely converts a nullable [Object] into a string.
  String _safeString(Object? val) => val?.toString() ?? '';

  /// Makes a string safe to use as an identifier by replacing any illegal characters
  /// with underscores and prefixing with an underscore if it starts with a digit.
  String _makeSafeIdentifier(String name) {
    var safe = name.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    if (RegExp('^[0-9]').hasMatch(safe)) {
      safe = '_$safe';
    }
    return safe;
  }
}

/// Factory function to create the [GenerateRouteInfoHelperBuilder].
Builder generateRouteInfoHelperBuilder(BuilderOptions options) =>
    GenerateRouteInfoHelperBuilder();

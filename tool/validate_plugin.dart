// Static validator for the repo-hosted AI assistant plugin (Claude + Codex).
//
// Run from the repository root:
//   dart tool/validate_plugin.dart
//
// Exits non-zero on any failure. No network, no credentials, no AI calls.

import 'dart:convert';
import 'dart:io';

final List<String> _errors = [];
final List<String> _warnings = [];

void fail(String message) => _errors.add(message);
void warn(String message) => _warnings.add(message);

final RegExp _kebab = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

Map<String, dynamic>? readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('missing file: $path');
    return null;
  }
  try {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException catch (e) {
    fail('invalid JSON in $path: ${e.message}');
    return null;
  }
}

String? pubspecVersion() {
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  return match?.group(1);
}

/// Extremely small frontmatter reader: returns the `name:`/`description:`
/// scalar values between the leading `---` fence pair.
Map<String, String> frontmatter(String path) {
  final lines = File(path).readAsLinesSync();
  final result = <String, String>{};
  if (lines.isEmpty || lines.first.trim() != '---') return result;
  for (final line in lines.skip(1)) {
    if (line.trim() == '---') break;
    final idx = line.indexOf(':');
    if (idx > 0) {
      result[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
  }
  return result;
}

void checkMarkdownRefs(File doc, Directory pluginRoot) {
  final content = doc.readAsStringSync();
  final links = RegExp(r'\]\(([^)#]+)\)').allMatches(content);
  for (final match in links) {
    final target = match.group(1)!.trim();
    if (target.startsWith('http://') || target.startsWith('https://')) {
      continue;
    }
    if (target.startsWith('/')) {
      fail('${doc.path}: absolute link "$target"');
      continue;
    }
    final resolved = File(
      Uri.file('${doc.parent.path}/').resolve(target).toFilePath(),
    );
    final canonicalRoot = pluginRoot.absolute.resolveSymbolicLinksSync();
    final canonicalTarget = resolved.absolute.path;
    if (!canonicalTarget.startsWith(canonicalRoot)) {
      fail('${doc.path}: link escapes the plugin root: "$target"');
    } else if (!resolved.existsSync()) {
      fail('${doc.path}: broken link "$target"');
    }
  }
  for (final needle in ['/Users/', r'C:\']) {
    if (content.contains(needle)) {
      fail('${doc.path}: contains machine-specific absolute path "$needle"');
    }
  }
  for (final secretHint in ['AKIA', 'BEGIN PRIVATE KEY', 'ghp_', 'sk-ant-']) {
    if (content.contains(secretHint)) {
      fail('${doc.path}: contains secret-like content "$secretHint"');
    }
  }
}

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    fail('run from the repository root (pubspec.yaml not found)');
    report();
    return;
  }

  const pluginDir = 'plugins/router-builder';
  final claudePlugin = readJson('$pluginDir/.claude-plugin/plugin.json');
  final codexPlugin = readJson('$pluginDir/.codex-plugin/plugin.json');
  final claudeMarket = readJson('.claude-plugin/marketplace.json');
  final codexMarket = readJson('.agents/plugins/marketplace.json');
  final version = pubspecVersion();
  if (version == null) fail('could not read version from pubspec.yaml');

  // --- version and identity sync ---------------------------------------
  final claudeEntry = (claudeMarket?['plugins'] as List?)
      ?.cast<Map<String, dynamic>>()
      .firstWhere((p) => true, orElse: () => {});
  for (final (label, value) in [
    ('claude plugin.json version', claudePlugin?['version']),
    ('codex plugin.json version', codexPlugin?['version']),
    ('claude marketplace entry version', claudeEntry?['version']),
  ]) {
    if (version != null && value != version) {
      fail('$label is "$value" but pubspec.yaml version is "$version"');
    }
  }
  final names = {
    'claude plugin.json': claudePlugin?['name'],
    'codex plugin.json': codexPlugin?['name'],
    'claude marketplace entry': claudeEntry?['name'],
    'codex marketplace entry':
        ((codexMarket?['plugins'] as List?)?.first
            as Map<String, dynamic>?)?['name'],
  };
  for (final entry in names.entries) {
    if (entry.value != 'router-builder') {
      fail('${entry.key}: plugin name "${entry.value}" != "router-builder"');
    }
  }
  for (final (label, market) in [
    ('claude marketplace', claudeMarket),
    ('codex marketplace', codexMarket),
  ]) {
    final name = market?['name'];
    if (name is! String || !_kebab.hasMatch(name)) {
      fail('$label: marketplace name "$name" is not kebab-case');
    } else if (name != 'router-builder-plugins') {
      fail('$label: marketplace name "$name" != "router-builder-plugins"');
    }
  }

  // --- marketplace source paths ----------------------------------------
  final claudeSource = claudeEntry?['source'];
  if (claudeSource != './$pluginDir') {
    fail('claude marketplace source "$claudeSource" != "./$pluginDir"');
  }
  final codexSource =
      ((codexMarket?['plugins'] as List?)?.first
              as Map<String, dynamic>?)?['source']
          as Map<String, dynamic>?;
  if (codexSource?['source'] != 'local' ||
      codexSource?['path'] != './$pluginDir') {
    fail(
      'codex marketplace source must be {source: local, path: ./$pluginDir}'
      ' (found $codexSource)',
    );
  }
  if (!Directory(pluginDir).existsSync()) {
    fail('plugin directory missing: $pluginDir');
  }

  // --- skills ------------------------------------------------------------
  final skillsDir = Directory('$pluginDir/skills');
  final skillNames = <String>{};
  if (!skillsDir.existsSync()) {
    fail('missing $pluginDir/skills');
  } else {
    final skillDirs =
        skillsDir.listSync().whereType<Directory>().toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (skillDirs.isEmpty) fail('no skills found under $pluginDir/skills');
    for (final dir in skillDirs) {
      final dirName = dir.path.split(Platform.pathSeparator).last;
      final skillFile = File('${dir.path}/SKILL.md');
      if (!skillFile.existsSync()) {
        fail('$dirName: missing SKILL.md');
        continue;
      }
      final fm = frontmatter(skillFile.path);
      final name = fm['name'];
      final description = fm['description'];
      if (name == null || name.isEmpty) {
        fail('$dirName/SKILL.md: missing frontmatter "name"');
      } else {
        if (name != dirName) {
          fail('$dirName/SKILL.md: frontmatter name "$name" != directory name');
        }
        if (!_kebab.hasMatch(name)) {
          fail('$dirName/SKILL.md: name "$name" is not kebab-case');
        }
        if (!skillNames.add(name)) fail('duplicate skill name "$name"');
      }
      if (description == null || description.length < 40) {
        fail(
          '$dirName/SKILL.md: description missing or too short to support '
          'discovery (needs the trigger conditions)',
        );
      }
      if ((name?.length ?? 0) + (description?.length ?? 0) > 1024) {
        warn(
          '$dirName/SKILL.md: frontmatter above 1024 chars; some clients '
          'truncate skill listings',
        );
      }
    }
  }

  // --- markdown link integrity across the plugin -------------------------
  final pluginRoot = Directory(pluginDir);
  for (final entity in pluginRoot.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.md')) {
      checkMarkdownRefs(entity, pluginRoot);
    }
  }

  // --- bundled codemod parity + permissions ------------------------------
  const canonical = 'tool/migrate_to_v3.sh';
  const bundled = '$pluginDir/skills/migrate-v2-to-v3/scripts/migrate_to_v3.sh';
  final canonicalFile = File(canonical);
  final bundledFile = File(bundled);
  if (!canonicalFile.existsSync() || !bundledFile.existsSync()) {
    fail('codemod script missing ($canonical or $bundled)');
  } else {
    if (!listEquals(
      canonicalFile.readAsBytesSync(),
      bundledFile.readAsBytesSync(),
    )) {
      fail(
        '$bundled is not byte-identical to $canonical '
        '(copy the canonical file over the bundled one)',
      );
    }
    if (!Platform.isWindows) {
      final mode = bundledFile.statSync().modeString();
      if (!mode.contains('x')) {
        warn(
          '$bundled is not executable (chmod +x); agents invoke it via '
          '"bash" so this is not fatal',
        );
      }
    }
  }

  // --- agents -------------------------------------------------------------
  final agentFile = File('$pluginDir/agents/route-auditor.md');
  if (!agentFile.existsSync()) {
    fail('missing $pluginDir/agents/route-auditor.md');
  } else {
    final fm = frontmatter(agentFile.path);
    for (final tool in ['Write', 'Edit']) {
      if ((fm['tools'] ?? '').split(',').map((t) => t.trim()).contains(tool)) {
        fail('route-auditor must stay read-only; found tool "$tool"');
      }
    }
  }

  // --- pub.dev archive hygiene -------------------------------------------
  final pubignore =
      File('.pubignore').existsSync()
          ? File('.pubignore').readAsStringSync()
          : '';
  for (final required in ['plugins/', 'AGENTS.md', 'CLAUDE.md']) {
    if (!pubignore.split('\n').map((l) => l.trim()).contains(required)) {
      fail(
        '.pubignore must exclude "$required" so pub.dev never ships a '
        'partial plugin tree (hidden manifests are auto-excluded)',
      );
    }
  }

  report();
}

bool listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void report() {
  for (final w in _warnings) {
    stdout.writeln('WARN  $w');
  }
  for (final e in _errors) {
    stdout.writeln('ERROR $e');
  }
  if (_errors.isEmpty) {
    stdout.writeln(
      'plugin validation passed '
      '(${_warnings.length} warning${_warnings.length == 1 ? '' : 's'})',
    );
  } else {
    stdout.writeln('plugin validation FAILED with ${_errors.length} error(s)');
    exitCode = 1;
  }
}

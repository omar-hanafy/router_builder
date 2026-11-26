/// Migrates Dart builder imports and exports from router_builder v3 to v4.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _oldPackage = 'package:router_builder';
const _oldUri = '$_oldPackage/builder.dart';
const _usage =
    'Usage: dart run router_builder_generator:migrate_builder_imports '
    '[--write] [file or directory ...]';

/// Previews changed directive locations, or applies the changes with `--write`.
void main(List<String> arguments) {
  var write = false;
  var positional = false;
  final paths = <String>[];
  for (final argument in arguments) {
    if (!positional && argument == '--') {
      positional = true;
    } else if (!positional && argument == '--write') {
      write = true;
    } else if (!positional && (argument == '--help' || argument == '-h')) {
      stdout.writeln(_usage);
      return;
    } else if (!positional && argument.startsWith('-')) {
      stderr.writeln('Unknown argument $argument\n$_usage');
      exitCode = 64;
      return;
    } else {
      paths.add(argument);
    }
  }

  try {
    final files = <String>{};
    for (final path in paths.isEmpty ? ['.'] : paths) {
      switch (FileSystemEntity.typeSync(path, followLinks: false)) {
        case FileSystemEntityType.directory:
          final directory = Directory(path).resolveSymbolicLinksSync();
          files.addAll(_dartFiles(Directory(directory)));
        case FileSystemEntityType.file when path.endsWith('.dart'):
          files.add(File(path).resolveSymbolicLinksSync());
        default:
          throw FileSystemException('Expected a Dart file or directory', path);
      }
    }
    var count = 0;
    for (final path in files.toList()..sort()) {
      count += _migrate(File(path), write: write);
    }
    stdout.writeln(
      '${write ? 'Updated' : 'Would update'} $count directive URI(s).',
    );
  } on FileSystemException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Iterable<String> _dartFiles(Directory directory) sync* {
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity.path;
    } else if (entity is Directory) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.') ||
          name == 'build' ||
          File.fromUri(entity.uri.resolve('pubspec.yaml')).existsSync()) {
        continue;
      }
      yield* _dartFiles(entity);
    }
  }
}

int _migrate(File file, {required bool write}) {
  final bytes = file.readAsBytesSync();
  final source = utf8.decode(bytes);
  final parsed = parseString(
    content: source,
    path: file.path,
    throwIfDiagnostics: false,
  );
  final edits = <(SimpleStringLiteral, String)>[];
  for (final directive
      in parsed.unit.directives.whereType<NamespaceDirective>()) {
    final uris = [directive.uri, ...directive.configurations.map((c) => c.uri)];
    for (final uri in uris) {
      if (uri.stringValue != _oldUri) continue;
      // A directive URI may span adjacent string literals separated by comments.
      // Insert into the component containing the end of the old package name.
      final parts = uri is AdjacentStrings ? uri.strings : [uri];
      var index = _oldPackage.length;
      for (final part in parts.whereType<SimpleStringLiteral>()) {
        if (index <= part.value.length) {
          edits.add((
            part,
            part.value.replaceRange(index, index, '_generator'),
          ));
          final location = parsed.lineInfo.getLocation(part.offset);
          stdout.writeln(
            '${file.path}:${location.lineNumber}:${location.columnNumber}',
          );
          break;
        }
        index -= part.value.length;
      }
    }
  }
  if (edits.isEmpty || !write) return edits.length;
  var updated = source;
  for (final (part, value) in edits.reversed) {
    updated = updated.replaceRange(
      part.contentsOffset,
      part.contentsEnd,
      value,
    );
  }
  final bom =
      bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf;
  final temp = file.parent.createTempSync('.router-builder-migration-');
  try {
    // A sibling temporary file can replace the source atomically.
    final replacement = file.copySync('${temp.path}/source.dart');
    replacement.writeAsStringSync(
      bom ? '\uFEFF$updated' : updated,
      flush: true,
    );
    if (Platform.isLinux || Platform.isMacOS) {
      // File.copySync on Linux applies the process umask to the new file.
      final mode = file.statSync().mode & 0xfff;
      if ((replacement.statSync().mode & 0xfff) != mode) {
        final chmod = Process.runSync('chmod', [
          mode.toRadixString(8),
          replacement.path,
        ]);
        if (chmod.exitCode != 0) {
          throw FileSystemException(
            'Could not preserve permissions: ${chmod.stderr}',
            file.path,
          );
        }
      }
    }
    replacement.renameSync(file.path);
  } finally {
    temp.deleteSync(recursive: true);
  }
  return edits.length;
}

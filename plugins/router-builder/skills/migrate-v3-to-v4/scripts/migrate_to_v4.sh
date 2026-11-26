#!/usr/bin/env bash
# Preview or apply the v3 to v4 YAML edits for packages using router_builder.
# Ruby's standard YAML parser supplies source positions so comments and custom
# dependency sources survive. No gems or network access are required.
set -eu
exec ruby - "$@" <<'RUBY'
require 'find'
require 'open3'
require 'optparse'
require 'psych'
require 'set'
require 'tempfile'

RUNTIME = 'router_builder'
GENERATOR = 'router_builder_generator'
VERSION = '^4.0.0'
OLD_KEY = 'router_builder:generate_route_info_helper'
NEW_KEY = 'router_builder_generator:generate_route_info_helper'
OLD_URI = 'package:router_builder/builder.dart'
NEW_URI = 'package:router_builder_generator/builder.dart'

class ManualEdit < StandardError; end

# Read the syntax tree without constructing user-supplied YAML objects.
def document(text)
  docs = Psych.parse_stream(text).children
  raise ManualEdit, 'expected one YAML mapping' unless docs.size == 1 &&
    docs.first.root.is_a?(Psych::Nodes::Mapping)
  docs.first.root
end

def entries(node)
  return {} if node.nil?
  raise ManualEdit, 'review the YAML mapping or alias' unless node.is_a?(Psych::Nodes::Mapping)
  raise ManualEdit, 'review the anchored or tagged YAML mapping' if node.anchor || node.tag
  result = {}
  node.children.each_slice(2) do |key, value|
    unless key.is_a?(Psych::Nodes::Scalar) && key.value != '<<' && !result.key?(key.value)
      raise ManualEdit, 'review the merged, complex, or duplicate YAML keys'
    end
    result[key.value] = [key, value]
  end
  result
end

def constrained_version?(node, major)
  return false unless node.is_a?(Psych::Nodes::Scalar)
  patch = "#{major}\\.\\d+\\.\\d+"
  /\A(?:\^?#{patch}|>=#{patch}\s+<#{major + 1}\.0\.0)\z/.match?(node.value)
end

# Keep the original quotes, spacing and comments. Positions refer to Unicode
# characters in the original text. Apply edits in reverse source order.
def scalar_edit(node, replacement)
  if node.start_line != node.end_line || node.anchor || node.tag
    raise ManualEdit, 'review the tagged, anchored, or multiline value'
  end
  quote = {Psych::Nodes::Scalar::DOUBLE_QUOTED => '"',
           Psych::Nodes::Scalar::SINGLE_QUOTED => "'"}.fetch(node.style, '')
  [node.start_line, node.start_column, node.end_column, "#{quote}#{replacement}#{quote}"]
end

def apply_edits(text, edits)
  lines = text.lines
  edits.sort.reverse_each do |line, start_column, end_column, value|
    lines[line] ||= ''
    lines[line][start_column...end_column] = value
  end
  lines.join
end

def dependencies(section)
  return {} unless section
  value = section.last
  return {} if value.is_a?(Psych::Nodes::Scalar) && value.value.empty? && value.plain
  entries(value)
end

def overrides?(manifest)
  overrides = dependencies(manifest['dependency_overrides'])
  overrides.key?(RUNTIME) || overrides.key?(GENERATOR)
end

def migrate_pubspec(path, text)
  root = document(text)
  manifest = entries(root)
  runtime_deps = dependencies(manifest['dependencies'])
  dev_deps = dependencies(manifest['dev_dependencies'])
  runtime = runtime_deps[RUNTIME] || dev_deps[RUNTIME]
  return unless runtime
  if runtime_deps.key?(RUNTIME) && dev_deps.key?(RUNTIME)
    raise ManualEdit, 'router_builder appears in both dependency sections'
  end
  local = File.join(File.dirname(path), 'pubspec_overrides.yaml')
  local_config = File.file?(local) ? entries(document(File.read(local))) : {}
  if [manifest, local_config].any? { |config| config.key?('workspace') || config.key?('resolution') }
    raise ManualEdit, 'review shared workspace dependencies and overrides across its members'
  end
  if overrides?(manifest) || overrides?(local_config)
    raise ManualEdit, 'preserve the explicit dependency override'
  end
  if !constrained_version?(runtime.last, 3) && !constrained_version?(runtime.last, 4)
    raise ManualEdit, 'review the router_builder constraint or custom source'
  end

  edits = []
  adding_generator = false
  edits << scalar_edit(runtime.last, VERSION) if constrained_version?(runtime.last, 3)
  generator = runtime_deps[GENERATOR] || dev_deps[GENERATOR]
  if generator
    if runtime_deps.key?(GENERATOR) && dev_deps.key?(GENERATOR)
      raise ManualEdit, 'the generator appears in both dependency sections'
    end
    raise ManualEdit, 'review the existing generator constraint or custom source' unless constrained_version?(generator.last, 4)
  elsif !runtime_deps.key?('build_runner') && !dev_deps.key?('build_runner')
    # A runtime-only dependency works on SDKs that cannot resolve the generator.
    if runtime_deps.key?('build') || dev_deps.key?('build') || File.file?(File.join(File.dirname(path), 'build.yaml'))
      raise ManualEdit, 'choose the generator dependency for this custom build package'
    end
  else
    adding_generator = true
    section = manifest['dev_dependencies']
    dev_map = section&.last
    inline_dev_map = dev_map.is_a?(Psych::Nodes::Mapping) && dev_map.style == Psych::Nodes::Mapping::FLOW
    if root.style == Psych::Nodes::Mapping::FLOW || inline_dev_map
      raise ManualEdit, 'add the generator to the inline dependency mapping'
    end
    key = (section || manifest.fetch('dependencies')).first
    unless key.start_column.zero? && key.start_line == key.end_line
      raise ManualEdit, 'add the generator to the indented or explicit dependency section'
    end
    newline = text.include?("\r\n") ? "\r\n" : "\n"
    if section
      line = section.first.start_line + 1
      indentation = dev_deps.empty? ? 2 : dev_deps.values.first.first.start_column
      prefix = line == text.lines.size && !text.end_with?("\n") ? newline : ''
      edits << [line, 0, 0, "#{prefix}#{' ' * indentation}#{GENERATOR}: #{VERSION}#{newline}"]
    else
      # Insert next to dependencies, including when the document ends with "...".
      line = manifest.fetch('dependencies').first.start_line
      edits << [line, 0, 0, "dev_dependencies:#{newline}  #{GENERATOR}: #{VERSION}#{newline}#{newline}"]
    end
  end
  return text if edits.empty?
  updated = apply_edits(text, edits)
  # Compare the complete data before writing any text edits. An insertion can
  # be valid YAML and still leave the generator in the wrong mapping.
  expected = Psych.safe_load(text)
  section = runtime_deps.key?(RUNTIME) ? 'dependencies' : 'dev_dependencies'
  raise ManualEdit, 'review the dependency section' unless expected[section].is_a?(Hash)
  expected[section][RUNTIME] = VERSION if constrained_version?(runtime.last, 3)
  (expected['dev_dependencies'] ||= {})[GENERATOR] = VERSION if adding_generator
  raise ManualEdit, 'review the location of the dependency edits' unless Psych.safe_load(updated) == expected
  updated
rescue Psych::BadAlias, Psych::DisallowedClass
  raise ManualEdit, 'review the YAML aliases or custom value types'
end

def rename_builder_names(nodes, edits)
  matches = nodes.select { |node| [OLD_KEY, NEW_KEY].include?(node.value.sub('|', ':')) }
  old = matches.find { |node| node.value.sub('|', ':') == OLD_KEY }
  return unless old
  raise ManualEdit, 'multiple spellings of the builder are already present' if matches.size > 1
  edits << scalar_edit(old, NEW_KEY)
end

def rename_builder_list(list, edits)
  return unless list
  unless list.is_a?(Psych::Nodes::Sequence) && list.children.all? { |node| node.is_a?(Psych::Nodes::Scalar) }
    raise ManualEdit, 'review the builder name list or alias'
  end
  rename_builder_names(list.children, edits)
end

def migrate_build(text)
  config = entries(document(text))
  edits = []
  globals = entries(config.dig('global_options', 1))
  rename_builder_names(globals.values.map(&:first), edits)
  rename_builder_names(entries(config.dig('triggers', 1)).values.map(&:first), edits)
  globals.each_value { |_, options| rename_builder_list(entries(options).dig('runs_before', 1), edits) }
  entries(config.dig('targets', 1)).each_value do |_, target|
    builders = entries(entries(target).dig('builders', 1))
    rename_builder_names(builders.values.map(&:first), edits)
  end
  %w[builders post_process_builders].each do |kind|
    entries(config.dig(kind, 1)).each_value do |_, definition|
      fields = entries(definition)
      uri = fields.dig('import', 1)
      edits << scalar_edit(uri, NEW_URI) if uri.is_a?(Psych::Nodes::Scalar) && uri.value == OLD_URI
      if kind == 'builders'
        %w[applies_builders runs_before].each { |field| rename_builder_list(fields.dig(field, 1), edits) }
      end
    end
  end
  apply_edits(text, edits)
end

write = false
OptionParser.new do |options|
  options.banner = 'Usage: migrate_to_v4.sh [--write] [directories or pubspec.yaml/build.yaml files]'
  options.on('-w', '--write', 'Apply the YAML changes (default: print a diff)') { write = true }
  options.on('-h', '--help', 'Show usage') { puts options; exit }
end.parse!
files = Set.new
(ARGV.empty? ? ['.'] : ARGV).each do |path|
  abort "Missing path: #{path}" unless File.exist?(path)
  Find.find(path) do |file|
    next if File.symlink?(file)
    name = File.basename(file)
    if File.directory?(file)
      Find.prune if file != path && (name.start_with?('.') || name == 'build')
    elsif %w[pubspec.yaml build.yaml].include?(name)
      files.add(File.expand_path(file))
    end
  end
end

changed = 0
files.group_by { |file| File.dirname(file) }.sort.each do |dir, selected|
  pubspec = File.join(dir, 'pubspec.yaml')
  next unless File.file?(pubspec) && !File.symlink?(pubspec)
  begin
    updated = migrate_pubspec(pubspec, File.read(pubspec))
    next unless updated
    changes = {}
    changes[pubspec] = updated if selected.include?(pubspec)
    build = File.join(dir, 'build.yaml')
    changes[build] = migrate_build(File.read(build)) if selected.include?(build)
    changes.each do |path, content|
      next if File.read(path) == content
      if write
        Tempfile.create(['.router-migration-', '.tmp'], dir) do |temp|
          temp.chmod(File.stat(path).mode & 07777)
          temp.write(content)
          temp.close
          File.rename(temp.path, path)
        end
        puts "Updated #{path}"
      else
        diff, status = Open3.capture2('diff', '-u', '-L', path, '-L', path, path, '-', stdin_data: content)
        abort "Could not preview #{path}" if status.exitstatus != 1
        puts diff
      end
      changed += 1
    end
  rescue ManualEdit, Psych::SyntaxError => error
    warn "Review #{dir} manually: #{error.message}"
  end
end
puts "#{write ? 'Updated' : 'Would update'} #{changed} file(s)."
RUBY

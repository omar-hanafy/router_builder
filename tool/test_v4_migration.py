#!/usr/bin/env python3
"""Verify the v3 builder migration against a published and a local package graph."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GENERATOR = ROOT / "generator"
FIXTURES = GENERATOR / "test_fixes"
CODEMOD = ROOT / "tool" / "migrate_to_v4.sh"


def run(args, cwd, *, umask=-1):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, umask=umask)
    if result.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}\n{result.stdout}{result.stderr}")
    return result.stdout + result.stderr


def write_fixture(parent, name, filename, content):
    path = parent / name / filename
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content.encode())
    return path


def check_codemod(temp, codemod=CODEMOD):
    runtime = "  router_builder: '^3.1.0' # navigation\n"
    gen = "  router_builder_generator: ^4.0.0\n"
    manifest = (
        "name: example_app\ndependencies:\n"
        + runtime
        + "dev_dependencies: # local tools\n  build_runner: ^2.15.0\n"
    )
    migrated = manifest.replace("^3.1.0", "^4.0.0").replace(
        "  build_runner:", gen + "  build_runner:"
    )
    old_key = "router_builder:generate_route_info_helper"
    new_key = "router_builder_generator:generate_route_info_helper"
    old_uri = "package:router_builder/builder.dart"
    new_uri = "package:router_builder_generator/builder.dart"
    build = (
        "targets:\n  $default:\n    builders:\n"
        f"      '{old_key}': # keep this comment\n        enabled: true\n"
        f"global_options:\n  {old_key}:\n    options:\n      note: {old_key}\n"
        f"builders:\n  wrap:\n    import: '{old_uri}'\n"
        "    builder_factories: [generateRouteInfoHelperBuilder]\n"
        "    build_extensions: {'$package$': [lib/wrapped.g.dart]}\n"
        f"    runs_before: ['{old_key}']\n    applies_builders:\n      - {old_key}\n"
        f"# {old_key}\n"
    )
    new_build = (
        build.replace(f"'{old_key}':", f"'{new_key}':")
        .replace(f"  {old_key}:\n", f"  {new_key}:\n")
        .replace(old_uri, new_uri)
        .replace(f"['{old_key}']", f"['{new_key}']")
        .replace(f"      - {old_key}", f"      - {new_key}")
    )

    existing_direct = manifest.replace(runtime, runtime + gen)
    anchored = manifest.replace("dev_dependencies:", "dev_dependencies: &shared") + "tools: *shared\n"
    conflict = build.replace(f"      '{old_key}':", f"      {new_key}: {{}}\n      '{old_key}':")
    cases = [
        ("application", "pubspec.yaml", manifest, migrated),
        ("application", "build.yaml", build, new_build),
        ("unrelated", "pubspec.yaml", "name: unrelated\n", None),
        ("unrelated", "build.yaml", build, None),
        ("custom_inline", "pubspec.yaml", manifest.replace("'^3.1.0'", "{path: ../runtime}"), None),
        ("custom_block", "pubspec.yaml", manifest.replace(runtime, "  router_builder:\n    git: https://example.org/router.git\n"), None),
        ("override", "pubspec.yaml", manifest + "dependency_overrides:\n  router_builder: {path: ../runtime}\n", None),
        ("separate_override", "pubspec.yaml", manifest, None),
        ("separate_override", "pubspec_overrides.yaml", "dependency_overrides:\n  router_builder_generator: {path: ../generator}\n", None),
        ("flow", "pubspec.yaml", manifest.replace("dev_dependencies: # local tools\n  build_runner: ^2.15.0", "dev_dependencies: {build_runner: ^2.15.0}"), None),
        ("comments", "pubspec.yaml", "name: other\ndescription: |\n  router_builder: ^3.1.0\n", None),
        ("external_builder", "pubspec.yaml", existing_direct, existing_direct.replace("^3.1.0", "^4.0.0")),
        ("anchored", "pubspec.yaml", anchored, None),
        ("builder_collision", "pubspec.yaml", manifest, None),
        ("builder_collision", "build.yaml", conflict, None),
    ]
    runtime_only = "name: library\ndependencies:\n" + runtime
    cases.append(("runtime_only", "pubspec.yaml", runtime_only, runtime_only.replace("^3.1.0", "^4.0.0")))
    wrapper = runtime_only + "  build: ^4.0.6\n"
    cases.extend([("custom_builder", "pubspec.yaml", wrapper, None),
                  ("custom_builder", "build.yaml", build, None)])
    uses_runner = "  build_runner: ^2.15.0\n"
    cases.append(("new_block", "pubspec.yaml", "name: app\ndependencies:\n" + runtime + uses_runner,
                  "name: app\ndev_dependencies:\n" + gen + "\ndependencies:\n" + runtime.replace("^3.1.0", "^4.0.0") + uses_runner))
    cases.append(("crlf", "pubspec.yaml", manifest.replace("\n", "\r\n"), migrated.replace("\n", "\r\n")))
    cr_build = f"global_options:\r  elsewhere:wrap:\r    runs_before:\r      - {old_key}\r"
    cases.extend([("cr", "pubspec.yaml", manifest.replace("\n", "\r"), migrated.replace("\n", "\r")),
                  ("cr", "build.yaml", cr_build, cr_build.replace(old_key, new_key))])
    mixed = manifest.replace("\n", "\r\n").replace("\r\n", "\r", 1)
    cases.append(("mixed_endings", "pubspec.yaml", mixed, mixed.replace("^3.1.0", "^4.0.0").replace(
        "  build_runner:", gen.replace("\n", "\r") + "  build_runner:"
    )))
    old_pipe, new_pipe = old_key.replace(":", "|"), new_key.replace(":", "|")
    pipe_build = build.replace(old_key, old_pipe)
    new_pipe_build = new_build.replace(f"note: {old_key}", f"note: {old_pipe}").replace(
        f"# {old_key}", f"# {old_pipe}"
    )
    cases.extend([("legacy_pipe", "pubspec.yaml", manifest, migrated),
                  ("legacy_pipe", "build.yaml", pipe_build, new_pipe_build)])
    flow_forms = {
        "flow_builder_list": f"global_options:\n  elsewhere:wrap:\n    runs_before: [{old_pipe}]\n",
        "flow_builder_map": f"targets:\n  $default:\n    builders: {{{old_pipe}: {{}}}}\n",
    }
    for label, source in flow_forms.items():
        cases.extend([(label, "pubspec.yaml", manifest, migrated),
                      (label, "build.yaml", source, source.replace(old_pipe, f"'{new_key}'"))])
    for label, reference in [("colon_order", old_key), ("pipe_order", old_pipe)]:
        source = f"global_options:\n  elsewhere:wrap:\n    runs_before: ['{reference}']\n"
        cases.extend([(label, "pubspec.yaml", manifest, migrated),
                      (label, "build.yaml", source, source.replace(reference, new_key))])

    manual = {"explicit_key", "explicit_builder", "duplicate_generator", "indented_dev", "indented_root", "workspace",
              "workspace/client", "workspace/overridden", "workspace_from_override"}
    for label, first, second in [
        ("old_pipe_new_colon", old_pipe, new_key),
        ("old_colon_new_pipe", old_key, new_pipe),
        ("both_old_spellings", old_pipe, old_key),
    ]:
        source = f"targets:\n  $default:\n    builders:\n      {first}: {{}}\n      {second}: {{}}\n"
        cases.extend([(label, "pubspec.yaml", manifest, None), (label, "build.yaml", source, None)])
        manual.add(label)
    list_conflict = f"global_options:\n  elsewhere:wrap:\n    runs_before: ['{old_pipe}', '{new_key}']\n"
    cases.extend([("ordering_collision", "pubspec.yaml", manifest, None),
                  ("ordering_collision", "build.yaml", list_conflict, None)])
    manual.add("ordering_collision")
    triggers = f"triggers:\n  {old_key}:\n    - annotation RT\n    - import router_builder/router_builder.dart\n"
    cases.extend([("trigger_keys", "pubspec.yaml", manifest, migrated),
                  ("trigger_keys", "build.yaml", triggers, triggers.replace(old_key, new_key))])

    explicit = manifest.replace("dev_dependencies: # local tools", "? dev_dependencies\n:")
    explicit_builder = manifest.replace("  build_runner: ^2.15.0", "  ? build_runner\n  : ^2.15.0")
    indented = "".join("  " + line for line in manifest.splitlines(keepends=True))
    indented_root = "  name: example_app\n  dependencies:\n    router_builder: ^3.1.0\n    build_runner: ^2.15.0\n"
    cases.extend([("explicit_key", "pubspec.yaml", explicit, None),
                  ("explicit_builder", "pubspec.yaml", explicit_builder, None),
                  ("duplicate_generator", "pubspec.yaml", existing_direct + gen, None),
                  ("indented_dev", "pubspec.yaml", indented, None),
                  ("indented_root", "pubspec.yaml", indented_root, None)])
    members = "workspace: [client, overridden, sibling]\n"
    sdk = "environment:\n  sdk: ^3.7.0\n"

    def workspace_manifest(name):
        return manifest.replace("example_app", name) + sdk

    cases.extend([
        ("workspace", "pubspec.yaml", workspace_manifest("root") + members, None),
        ("workspace/client", "pubspec.yaml", workspace_manifest("client") + "resolution: workspace\n", None),
        ("workspace/client", "build.yaml", build, None),
        ("workspace/overridden", "pubspec.yaml", workspace_manifest("overridden"), None),
        ("workspace/overridden", "pubspec_overrides.yaml", "resolution: workspace\n", None),
        ("workspace/sibling", "pubspec.yaml", "name: sibling\n" + sdk + "resolution: workspace\n", None),
        ("workspace/sibling", "pubspec_overrides.yaml", "dependency_overrides:\n  router_builder: {path: ../../runtime}\n", None),
        ("workspace_from_override", "pubspec.yaml", workspace_manifest("local_root"), None),
        ("workspace_from_override", "pubspec_overrides.yaml", "workspace: [app]\n", None),
        ("workspace_from_override/app", "pubspec.yaml", "name: app\n" + sdk + "resolution: workspace\n", None),
    ])
    originals, expected = {}, {}
    for package, filename, original, updated in cases:
        path = write_fixture(temp, package, filename, original)
        originals[path] = original.encode()
        expected[path] = (original if updated is None else updated).encode()

    preview = run(["bash", str(codemod), str(temp)], temp)
    if "--- " not in preview or any(p.read_bytes() != data for p, data in originals.items()):
        raise AssertionError("The preview must show a diff and preserve all inputs")
    applied = run(["bash", str(codemod), "--write", str(temp)], temp)
    # Check the semantic values with the parser used by the codemod itself.
    flow_list, flow_map = json.loads(run([
        "ruby", "-rpsych", "-rjson", "-e",
        "puts JSON.generate(ARGV.map { |file| Psych.safe_load(File.read(file)) })",
        *(temp / name / "build.yaml" for name in flow_forms),
    ], temp))
    if (flow_list["global_options"]["elsewhere:wrap"]["runs_before"] != [new_key]
            or flow_map["targets"]["$default"]["builders"] != {new_key: {}}):
        raise AssertionError("The migrated flow collections must contain the canonical builder key")
    mismatches = [str(path.relative_to(temp)) for path, data in expected.items() if path.read_bytes() != data]
    missing_notices = sorted(name for name in manual if f"Review {temp / name} manually:" not in preview)
    if mismatches or missing_notices:
        raise AssertionError(f"Unexpected YAML outputs: {mismatches}\nMissing manual reviews: {missing_notices}")
    second = run(["bash", str(codemod), "--write", str(temp)], temp)
    changed_dirs = {path.parent for path, data in expected.items() if data != originals[path]}
    if any(f"Review {path} manually:" in result for path in changed_dirs for result in (preview, applied, second)):
        raise AssertionError("A migrated package unexpectedly needed manual review")
    if "Updated 0 file(s)." not in second or any(p.read_bytes() != data for p, data in expected.items()):
        raise AssertionError("Second migration changed an already migrated fixture")
    print(f"YAML migration passed for {len(cases)} files, including preview and repeat runs.", flush=True)


def check_package_boundaries(app, command):
    old = b"export 'package:router_builder/builder.dart';\n"
    new = b"export 'package:router_builder_generator/builder.dart';\n"
    nested = [
        app / "packages" / "v3_tools",
        app / "lib" / "fixtures" / "v3_example",
    ]
    legacy_files = []
    for package in nested:
        source = package / "lib" / "legacy.dart"
        source.parent.mkdir(parents=True)
        (package / "pubspec.yaml").write_text(
            f"name: {package.name}\n"
            "environment:\n  sdk: ^3.11.0\ndependencies:\n  router_builder: 3.1.0\n"
        )
        source.write_bytes(old)
        legacy_files.append(source)

    targets = {app / "lib" / "group_writable.dart": 0o664, app / "lib" / "executable.dart": 0o755}
    for source, mode in targets.items():
        source.write_bytes(old)
        if os.name == "posix":
            source.chmod(mode)
    preview = run(command, app)
    if any(str(p.resolve()) in preview for p in legacy_files):
        raise AssertionError("Default preview entered a nested package")
    if any(source.read_bytes() != old for source in [*targets, *legacy_files]):
        raise AssertionError("The preview changed a source file")
    run(command + ["--write"], app, umask=0o077 if os.name == "posix" else -1)
    if any(p.read_bytes() != old for p in legacy_files):
        raise AssertionError("Default write migrated a nested v3 package")
    for source, mode in targets.items():
        if source.read_bytes() != new:
            raise AssertionError(f"Default write missed {source}")
        if os.name == "posix" and source.stat().st_mode & 0o7777 != mode:
            raise AssertionError(f"Atomic migration changed mode {mode:o} for {source}")

    # An explicitly chosen package is its own root, and a file is also a target.
    run(command + ["--write", str(nested[0]), str(legacy_files[1])], app)
    if any(p.read_bytes() != new for p in legacy_files):
        raise AssertionError("An explicit nested package or file was skipped")
    if os.name == "posix":
        # The OS resolves ".." after following the parent symlink. Each
        # lexically similar file is a negative control for a wrong-file write.
        aliases, physical = app / "aliases", app / "physical"
        (physical / "inner").mkdir(parents=True)
        aliases.mkdir()
        link = aliases / "shortcut"
        link.symlink_to(physical / "inner", target_is_directory=True)
        names = ["provided.dart", "directory/entry.dart"]
        for parent in (aliases, physical):
            (parent / "directory").mkdir()
            for name in names:
                (parent / name).write_bytes(old)
        run(command + ["--write", str(link / ".." / names[0]), str(link / ".." / "directory")], app)
        for name in names:
            if (physical / name).read_bytes() != new or (aliases / name).read_bytes() != old:
                raise AssertionError(f"An explicit symlink-parent path rewrote the wrong file for {name}")
    print("Package boundaries, explicit nested targets and atomic write permissions passed.", flush=True)


def check_dart_fixes(app, *, standalone=False):
    dedicated = app / "lib" / "directives"
    elements = app / "lib" / "elements"
    dedicated.mkdir(parents=True)
    elements.mkdir()
    originals, expected = {}, {}
    element_inputs = sorted(FIXTURES.glob("*.dart"))
    for path in element_inputs:
        golden = path.with_suffix(".dart.expect")
        shutil.copyfile(path, elements / path.name)
        shutil.copyfile(golden, elements / golden.name)
        originals[path.name], expected[path.name] = path.read_bytes(), golden.read_bytes()
    for before in sorted((FIXTURES / "directives").glob("*.before")):
        name = before.stem + ".dart"
        originals[name] = before.read_bytes()
        expected[name] = before.with_suffix(".after").read_bytes()
    # Preserve a UTF-8 BOM and CRLF in a source file with an eligible directive.
    for table in (originals, expected):
        table["windows.dart"] = b"\xef\xbb\xbf" + table["prefixed.dart"].replace(b"\n", b"\r\n")
    if not element_inputs or len(expected) <= len(element_inputs):
        raise AssertionError("Missing Dart fix or directive cases")
    for name, data in originals.items():
        (dedicated / name).write_bytes(data)
    shutil.copyfile(FIXTURES / "analysis_options.yaml", app / "analysis_options.yaml")
    pubspec = app / "pubspec.yaml"
    header = (
        "name: router_builder_migration_test\npublish_to: none\n"
        "environment:\n  sdk: '>=3.11.0 <4.0.0'\ndependencies:\n"
    )
    if standalone:
        # The generator's Dart-only SDK floor can precede the matching Flutter
        # release. These are the two real runtime sources used by the fixtures.
        runtime = app.parent / "runtime_surface"
        (runtime / "lib").mkdir(parents=True)
        (runtime / "pubspec.yaml").write_text("name: router_builder\nversion: 4.0.0\nenvironment:\n  sdk: ^3.11.0\n")
        shutil.copyfile(ROOT / "lib/builder.dart", runtime / "lib/builder.dart")
        shutil.copyfile(ROOT / "lib/src/annotations/route.dart", runtime / "lib/router_builder.dart")
        package_tool = "dart"
    else:
        runtime = ROOT
        package_tool = "flutter"
        pubspec.write_text(header + "  router_builder: 3.1.0\n")
        run(["flutter", "pub", "get"], app)
        run(["dart", "analyze", "--fatal-infos", "lib"], app)
        print(f"All {len(originals)} directive cases compile against pub.dev router_builder 3.1.0.", flush=True)

    pubspec.write_text(
        header
        + f"  router_builder:\n    path: {json.dumps(str(runtime))}\n"
        + f"  router_builder_generator:\n    path: {json.dumps(str(GENERATOR))}\n"
    )
    run([package_tool, "pub", "get"], app)
    command = ["dart", "run", "router_builder_generator:migrate_builder_imports"]
    preview = run(command + ["lib/directives"], app)
    if "Would update 0 " in preview or any((dedicated / n).read_bytes() != data for n, data in originals.items()):
        raise AssertionError(f"Unexpected Dart directive preview:\n{preview}")
    print(run(command + ["--write", "lib/directives"], app).strip(), flush=True)
    for name, data in expected.items():
        if (dedicated / name).read_bytes() != data:
            raise AssertionError(f"The portable directive migration differs from the golden for {name}")
    if "Updated 0 directive URI(s)." not in run(command + ["--write", "lib/directives"], app):
        raise AssertionError("The directive migration should be idempotent")

    print(run(["dart", "fix", "lib/elements", "--compare-to-golden"], app).strip(), flush=True)
    for _ in range(2):
        print(run(["dart", "fix", "--apply", "lib/elements"], app).strip(), flush=True)
        for path in element_inputs:
            if (elements / path.name).read_bytes() != expected[path.name]:
                raise AssertionError(f"The Dart element fix differs from {path.name}.expect")
    run(["dart", "analyze", "--fatal-infos", "lib"], app)
    print("The directive and Dart fix consumers analyze cleanly.", flush=True)
    check_package_boundaries(app, command)


if __name__ == "__main__":
    if sys.argv[1:] not in ([], ["--standalone"]):
        sys.exit("Usage: python3 tool/test_v4_migration.py [--standalone]")
    standalone = bool(sys.argv[1:])
    with tempfile.TemporaryDirectory(prefix="router-builder-migration-") as scratch:
        temp = Path(scratch)
        if not standalone:
            check_codemod(temp / "yaml")
        check_dart_fixes(temp / "dart", standalone=standalone)

#!/usr/bin/env python3
"""Verify the v3 builder migration against a published and a local package graph."""

import json
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GENERATOR = ROOT / "generator"
FIXTURES = GENERATOR / "test_fixes"
CODEMOD = ROOT / "tool" / "migrate_to_v4.sh"


def run(args, cwd):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
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
        ("flow", "pubspec.yaml", manifest.replace("dev_dependencies: # local tools\n  build_runner: ^2.15.0", "dev_dependencies: {}"), None),
        ("comments", "pubspec.yaml", "name: other\ndescription: |\n  router_builder: ^3.1.0\n", None),
        ("external_builder", "pubspec.yaml", existing_direct, existing_direct.replace("^3.1.0", "^4.0.0")),
        ("anchored", "pubspec.yaml", anchored, None),
        ("builder_collision", "pubspec.yaml", manifest, None),
        ("builder_collision", "build.yaml", conflict, None),
    ]
    cases.append(("new_block", "pubspec.yaml", "name: app\ndependencies:\n" + runtime,
                  "name: app\ndev_dependencies:\n" + gen + "\ndependencies:\n" + runtime.replace("^3.1.0", "^4.0.0")))
    cases.append(("crlf", "pubspec.yaml", manifest.replace("\n", "\r\n"), migrated.replace("\n", "\r\n")))
    originals, expected = {}, {}
    for package, filename, original, updated in cases:
        path = write_fixture(temp, package, filename, original)
        originals[path] = original.encode()
        expected[path] = (original if updated is None else updated).encode()

    preview = run(["bash", str(codemod), str(temp)], temp)
    if "--- " not in preview or any(p.read_bytes() != data for p, data in originals.items()):
        raise AssertionError("The preview must show a diff and preserve all inputs")
    run(["bash", str(codemod), "--write", str(temp)], temp)
    for path, data in expected.items():
        if path.read_bytes() != data:
            raise AssertionError(f"Unexpected codemod output in {path.relative_to(temp)}\n{path.read_bytes()!r}")
    second = run(["bash", str(codemod), "--write", str(temp)], temp)
    if "Updated 0 file(s)." not in second or any(p.read_bytes() != data for p, data in expected.items()):
        raise AssertionError("Second migration changed an already migrated fixture")
    print(f"YAML migration passed for {len(cases)} files, including preview and repeat runs.", flush=True)


def check_dart_fixes(app):
    source = app / "lib"
    source.mkdir(parents=True)
    fixtures = sorted(FIXTURES.glob("*.dart"))
    goldens = sorted(FIXTURES.glob("*.dart.expect"))
    if not fixtures or {p.name + ".expect" for p in fixtures} != {p.name for p in goldens}:
        raise AssertionError("Every migration input needs a matching golden")
    for path in fixtures + goldens:
        shutil.copyfile(path, source / path.name)
    shutil.copyfile(FIXTURES / "analysis_options.yaml", app / "analysis_options.yaml")
    pubspec = app / "pubspec.yaml"
    header = (
        "name: router_builder_migration_test\npublish_to: none\n"
        "environment:\n  sdk: '>=3.7.0 <4.0.0'\ndependencies:\n"
    )
    pubspec.write_text(header + "  router_builder: 3.1.0\n")
    run(["flutter", "pub", "get"], app)
    run(["dart", "analyze", "--fatal-infos", "lib"], app)
    print(f"All {len(fixtures)} inputs analyze against pub.dev router_builder 3.1.0.", flush=True)

    pubspec.write_text(
        header
        + f"  router_builder:\n    path: {json.dumps(str(ROOT))}\n"
        + f"  router_builder_generator:\n    path: {json.dumps(str(GENERATOR))}\n"
    )
    run(["flutter", "pub", "get"], app)
    print(run(["dart", "fix", "lib", "--compare-to-golden"], app).strip(), flush=True)
    for _ in range(2):
        print(run(["dart", "fix", "--apply", "lib"], app).strip(), flush=True)
        for path in fixtures:
            if (source / path.name).read_bytes() != (FIXTURES / (path.name + ".expect")).read_bytes():
                raise AssertionError(f"The migrated consumer differs from {path.name}.expect")
    run(["dart", "analyze", "--fatal-infos", "lib"], app)
    print("The migrated consumer analyzes cleanly after a repeat run.", flush=True)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="router-builder-migration-") as scratch:
        temp = Path(scratch)
        check_codemod(temp / "yaml")
        check_dart_fixes(temp / "dart")

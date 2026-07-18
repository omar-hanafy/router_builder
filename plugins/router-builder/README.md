# router-builder plugin (Claude Code + OpenAI Codex)

Package-specific AI coding-assistant support for the
[router_builder](https://pub.dev/packages/router_builder) Flutter package.
One plugin directory serves both platforms: `.claude-plugin/plugin.json` for
Claude Code and `.codex-plugin/plugin.json` for Codex, sharing a single
`skills/` tree.

This plugin extends the coding agent working on YOUR app. It adds no runtime
code, dependency, or telemetry to your Flutter app, and it is distributed from
the source repository, not inside the pub.dev package archive.

## Install

Claude Code (CLI v2.x):

```
/plugin marketplace add omar-hanafy/router_builder
/plugin install router-builder@router-builder-plugins
```

Codex (CLI 0.144+; also ChatGPT desktop/web Work mode - not the IDE extension):

```
codex plugin marketplace add omar-hanafy/router_builder
codex plugin add router-builder@router-builder-plugins
```

Start a new session after installing so the skills load. Update later with the
platform's marketplace update/upgrade command; remove with the platform's
uninstall/remove command.

## Skills

| Skill | Use it when |
|---|---|
| `setup-router-builder` | First-time integration; wiring RoutesHelper into GoRouter/Navigator; app-wide defaults |
| `add-route` | Adding/renaming/removing screens, tabs, popups, redirects, deep links |
| `debug-route-policy` | Auth gates, duplicate handling, popup/global/nav-bar behavior resolving unexpectedly |
| `debug-deep-links` | Links opening the wrong screen or nothing; custom-scheme vs https differences; allowedHosts questions |
| `debug-generation` | routes.g.dart missing/stale; RouterBuilderError; @RT discovery; analyzer/dependency conflicts; builder options |
| `review-routes` | Auditing all route declarations for auth gaps, key collisions, policy misuse |
| `upgrade-router-builder` | Choosing the upgrade path between majors |
| `migrate-v2-to-v3` | The breaking 2.x -> 3.x migration (bundled codemod + manual folds) |

On both platforms skills are namespaced `router-builder:<skill>`: invoke
`/router-builder:add-route` in Claude Code, or mention
`$router-builder:add-route` (or browse `/skills`) in Codex - and both
platforms also trigger them automatically when your request matches a skill
description.

Example prompts:

- "Add an orders screen at /orders/:orderId, deep-linkable, auth required."
- "Why does myapp://profile/9 not open the profile screen?"
- "Upgrade this app from router_builder 2 to 3."
- "Audit our routes for auth gaps before release."

## Claude-only components

- `agents/route-auditor.md`: a read-only subagent that runs the
  `review-routes` checklist across large codebases and returns a findings
  table. Claude invokes it automatically for route audits, or mention
  `route-auditor` explicitly. Codex ignores the `agents/` directory.
- `evals/`: knowledge-probe eval cases for `claude plugin eval` (early-access
  feature). They double as documented expected-behavior scenarios.

## Trust and permissions

- Skills are instructions plus reference documents; they run no code by
  themselves.
- The one bundled executable is `skills/migrate-v2-to-v3/scripts/migrate_to_v3.sh`,
  a dry-run-by-default, perl-based textual codemod (byte-identical copy of
  `tool/migrate_to_v3.sh` in the package repo; CI-verified parity). Agents are
  instructed to show you the dry-run diff before applying `--write`.
- No hooks, no MCP servers, no network access, no telemetry.
- The `route-auditor` agent is restricted to read-only tools.

## Compatibility

- Skill content targets router_builder 3.x (and knows how to recognize and
  migrate 2.x code). The plugin version tracks the package version.
- Claude Code >= 2.x (plugins + marketplaces). Codex CLI >= 0.144 / ChatGPT
  Work mode (plugins are not available in the Codex IDE extension or mobile).

## Maintainers: adding capabilities

- One canonical skill tree here; keep each skill's heavy facts in its
  `references/` file and verify them against `lib/src/` before editing.
- Every future BREAKING package release must add: a `tool/migrate_to_vN.sh`
  codemod (dry-run default), a MIGRATION_GUIDE.md section (template at its
  bottom), a new `migrate-vN-1-to-vN` skill in this plugin, and an update to
  `upgrade-router-builder`'s routing table.
- Bump BOTH plugin.json versions and BOTH marketplace entries with the package
  version; `dart tool/validate_plugin.dart` (repo root) enforces sync, and
  `claude plugin validate . --strict` must pass.

---
name: review-routes
description: Use when proactively auditing a Flutter app's router_builder route definitions while nothing is failing yet - before a release, after adding many routes, when asked to "check our routes/deep links/auth gating", or when hunting for misconfigured RoutePolicy, latent deep-link key conflicts, or auth gaps across @RT declarations.
---

# Review router_builder routes (package-principles audit)

A read-only audit of every `@RT` declaration and the wiring around them,
against the package's actual semantics. Report findings with file:line,
severity, and a concrete fix; change nothing unless the user asks.

In Claude Code, large codebases (50+ routes) are better audited by delegating
to the `route-auditor` subagent, which runs this same checklist in an isolated
context and returns the findings table.

## Inventory first

```bash
grep -rn "@RT()" lib/ | grep -v ".g.dart"          # all declarations
grep -rn "@RTConfig\|setDefaults\|installDefaults" lib/
grep -rn "deepLinkNames\|deepLinkHandler\|resolveDeepLink\|DeepLinkMatcher" lib/ | grep -v ".g.dart"
```

Record: route count, declaration idiom, the effective app-wide defaults (the
built-ins are `mustBeAuthorized: true`, `deepLinkAllowed: true`,
`deepLinkPushGlobally: true`, `duplicateBehavior: duplicate`), and where
defaults are installed relative to first use.

## Checklist (each item: what to look for -> why it is a finding)

Auth surface (highest severity):
1. With PUBLIC-by-default app defaults (`mustBeAuthorized: false`): list every
   route that does NOT explicitly set `mustBeAuthorized: true` and contains
   sensitive UI (account, payments, admin, personal data) -> unauthenticated
   access.
2. With PRIVATE-by-default defaults: routes that must stay reachable while
   logged out (login, onboarding, password reset, public deep-link landings)
   missing `RoutePolicy.public` -> login loops or dead deep links.
3. Deep-linkable private routes: `deepLinkAllowed` true (the default) on
   sensitive routes without a guard in the app's link entry path -> auth
   bypass via URI. The matcher itself performs NO auth.
4. Guard code calling `RouteArgsX.requiresAuth` on possibly-null args -> null
   means `false` (public); verify intent.

Deep-link topology:
5. Key uniqueness under the build rule (name + first non-param path segment +
   aliases): collisions that only have not fired because `fail_on_conflict:
   false` was set -> restore true and resolve ownership.
6. Routes users open by NAME via custom scheme (`myapp://<name>/...`) where
   the name is neither the first template segment nor an alias -> link dead at
   runtime despite appearing in `deepLinkMap`.
7. Multi-param templates read via `args.id` -> id heuristic returns the LAST
   segment; must use `args.pathParams['param']`.

Policy hygiene:
8. Branch routes setting `pushGlobally`/`isPopupRoute`/`deepLinkPushGlobally`,
   or redirect routes setting `isPopupRoute`/`visibleNavBar`/
   `shouldReplaceAll` -> debug asserts, silently forced in release; delete the
   dead fields.
9. All branch routes share ONE `branchParentType` enum type; `branchIndex`
   values within a shell are unique and contiguous from 0 (the shell UI
   indexes by position).
10. Policies restating the app default field-by-field -> noise; policies whose
    every field equals a preset -> use `RoutePolicy.global`/`public`/`popup`.
11. Category getters (`authorizedRoutes`, `globalRoutes`, ...) read before
    defaults installation in the boot path -> values computed from built-ins.

Wiring:
12. The adapter's push choke point reads route-level getters where per-call
    overrides matter (`route.pushGlobally` vs `args.effectivePushGlobally`)
    or never implements `effectiveDuplicateBehavior`/
    `effectiveShouldReplaceAll` -> policies declared but not enacted.
13. `resumeTo` captured but never cleared (`args.cleared()`) on resume ->
    resume loops; `resumeTo` never consumed after auth -> dead interception.
14. Hand edits inside the generated file (`routes.g.dart` header says DO NOT
    MODIFY) -> lost on next build.

## Report format

| # | Severity (blocker/warn/info) | File:line | Finding | Fix |

Lead with auth-surface findings. State the app-wide defaults you verified and
any checklist items that produced NO findings (so the user knows they were
checked, not skipped). Where a fix needs product judgment (which route owns a
contested alias, whether a screen is truly public), ask instead of assuming.

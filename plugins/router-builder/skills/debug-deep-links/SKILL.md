---
name: debug-deep-links
description: Use when a deep link in a router_builder Flutter app opens the wrong screen or nothing at all, RoutesHelper.resolveDeepLink or DeepLinkMatcher.match returns null, custom-scheme links (myapp://...) behave differently from https links, allowedHosts seem ignored, deepLinkMap keys do not resolve, or the build fails with deep-link key conflicts.
---

# Debug deep links (router_builder)

Resolution is two deterministic steps: `normalizeToAppPath` (URI -> app path)
then `match` (path -> route by TEMPLATE, else by ALIAS). Almost every "link
does nothing" bug is explained by the exact semantics in
[references/deep-link-resolution.md](references/deep-link-resolution.md) -
read it before theorizing.

## Step 1: Reproduce in isolation

Bypass the platform and the app's link plumbing first; feed the URI straight
into the package (a dart test or a debug print both work):

```dart
final incoming = Uri.parse('myapp://details/42'); // the reported link, verbatim
final normalized = RoutesHelper.normalizeToAppPath(incoming, allowedHosts: kAllowedHosts);
final match = RoutesHelper.resolveDeepLink(incoming, allowedHosts: kAllowedHosts);
print('normalized=$normalized match=${match?.route.name} args=${match?.args.report()}');
```

If this resolves correctly, the bug is in DELIVERY (app_links/GoRouter
onEnter/notification handler, guards, or the app's own resolution service -
some apps bypass `resolveDeepLink` entirely; find where the URI actually
enters). If it does not resolve, continue.

## Step 2: Classify by symptom

| Symptom | Likely cause | Check |
|---|---|---|
| Custom-scheme link fails, https form works | The URI HOST is promoted to the first path segment (`myapp://details/42` -> `/details/42`), which matches no template/alias | Compare normalized path against the route's `path` template and `deepLinkNames` |
| "The key is in deepLinkMap but does not resolve" | Runtime matcher NEVER reads route names or `deepLinkMap`; only templates + aliases | Add the name to `deepLinkNames`, or align the path's first segment |
| https link dead for a real subdomain | Host list wrong: matching is exact-or-suffix (`myapp.com` covers `www.myapp.com`, NOT `myapp-web.com`) | Audit the `allowedHosts` list |
| Link resolves for some IDs, wrong params | `args.id` heuristic is `pathParams['id']` else LAST segment; multi-param templates need `args.pathParams['name']` | Inspect `match.args.report()` |
| Wrong route wins between overlapping paths | First match wins in `allRoutes` order; equal segment-count + exact static segments (case-sensitive) required | Reorder is not possible; disambiguate templates |
| Route never matches at all | Resolved `deepLinkAllowed` is false (route policy or a global default) | `route.report()['resolvedPolicy']` |
| Opens inside the wrong navigator/tab | `deepLinkPushGlobally` (default true; branches force false) drives the args' `pushGlobally` | `match.args.effectivePushGlobally` |
| Build fails: `Deep-link key conflict(s)` | Two routes claim one key (name / first path segment / alias) | Reassign ownership; do NOT silence with `fail_on_conflict: false` |

## Step 3: Fix at the declaration, verify at the pipeline

Fix in the route declaration (path, `deepLinkNames`, policy) or in the
app-side allow-list; regenerate with `dart run build_runner build` when
declarations changed; re-run the Step 1 probe plus a regression case for the
previously-working links (template form, alias form, https form). Add the probe
as a real test when the project has a test suite.

## Escalation

- Delivery-side bugs (URI never reaches the resolver): trace the app's entry
  points - GoRouter route information/onEnter, app_links/uni_links, or push
  notification handlers; that wiring is app code, not this package.
- Behavior after a v2 upgrade: v2 matched hosts by SUBSTRING; v3 is
  exact-or-suffix, and previously-tolerated look-alike hosts now fail. See the
  `migrate-v2-to-v3` skill.
- `deepLinkHandler` side effects not firing: the matcher never invokes
  handlers; the app must call `canHandle`/`createAction` after matching.

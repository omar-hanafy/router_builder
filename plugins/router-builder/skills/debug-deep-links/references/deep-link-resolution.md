# Deep-link resolution reference (router_builder v3)

Verified against `lib/src/deeplink/deep_link_matcher.dart`,
`lib/src/models/route_args.dart` (`fromUri`), and the generator at v3.0.x.

## Pipeline

`RoutesHelper.resolveDeepLink(incoming, allowedHosts: [...])` does exactly:

1. `DeepLinkMatcher.normalizeToAppPath(incoming, hosts: allowedHosts)`
2. `const DeepLinkMatcher().match(normalized, RoutesHelper.allRoutes, original: incoming)`

Returns `DeepLinkMatch { route, args }` or `null`. The package never launches
platform links itself; delivering URIs into the app (app_links, GoRouter's
route information / onEnter, push notifications) is app code.

## Step 1: normalizeToAppPath

Given `incoming` and lowercase-compared `hosts`:

| Case | Result |
|---|---|
| No scheme (`/items/1`) | Returned unchanged. |
| `http`/`https` AND host matches an allowed host (exact `host == allowed` OR suffix `host.endsWith('.allowed')`) | Path-only URI keeping path (empty path becomes `/`) and query. |
| Any scheme with EMPTY host (`myapp:///items/1`) | Path-only URI from the segments. |
| Everything else, including custom schemes with a host (`myapp://items/1`) AND http(s) with a NON-allowed host | HOST IS PROMOTED to the first path segment: `myapp://items/1` becomes `/items/1`; `https://evil.com/items/1` becomes `/evil.com/items/1`. |

Consequences that surprise people:

- `myapp://details/42`: `details` is the URI HOST, and it becomes the first
  path segment. Whether it matches depends on templates/aliases (step 2), not
  on the route name.
- A non-allowed https host is NOT rejected outright; it degrades into the
  host-promotion branch and almost always fails matching. Do not rely on that
  as a security boundary; keep `allowedHosts` accurate.
- Host matching is exact-or-suffix. `myapp.com` accepts `myapp.com` and
  `www.myapp.com` but rejects `evil-myapp.com`. (v2 used substring `contains`,
  which accepted look-alike hosts; v3 fixed this. Audit lists on upgrade.)
- Query parameters are preserved; URI fragments are dropped.

## Step 2: match

Over `routes` (use `allRoutes`; it includes redirect-only routes):

1. Filter to routes whose RESOLVED `deepLinkAllowed` is true (so a global
   `deepLinkAllowed: false` default disables all matching unless routes opt in).
2. If the normalized path has NO segments: first route whose own template is
   empty wins (only `path: '/'` routes have an empty template; the default path
   is `/name`, which is non-empty).
3. Template pass, in `allRoutes` order: a route matches when segment COUNTS are
   equal and every non-parameter segment is EXACTLY equal (case-sensitive).
   `:param` segments (length > 1) match anything. First match wins, so
   overlapping templates resolve by order: branches first, then non-branch
   routes in scan order.
4. Alias pass (only if no template matched): the FIRST segment, lowercased, is
   compared against each route's `deepLinkNames`, lowercased. First route with
   a matching alias wins. Later segments are ignored for alias selection but
   still feed the args - and `pathParams` extraction stays POSITIONAL against
   the route's template, so an alias URL only fills parameters correctly when
   its segment layout mirrors the template (`/item/42` fills
   `/orders/:orderId`'s index-1 param; a differently-shaped alias URL yields
   empty or wrong `pathParams`).

CRITICAL: the runtime matcher never consults route NAMES. `RoutesHelper.deepLinkMap`
contains name keys (name + first template segment + aliases) for app-side
lookup tables, but `resolveDeepLink`/`match` do not read `deepLinkMap` at all.
"The key is in deepLinkMap" does NOT imply "the URI will match". A link whose
first segment equals a route's NAME resolves only when that segment also equals
the route's first template segment or one of its `deepLinkNames`.

## Step 3: args construction

On match, args are built as
`RouteArgs.fromUri(route, normalizedUri).copyWith(policy: RoutePolicy(pushGlobally: route.resolvedPolicy.deepLinkPushGlobally), object: original ?? normalized)`:

- `pathParams`: extracted positionally against the route's template.
- `id` heuristic: `pathParams['id']`, else the LAST path segment (even for
  routes without an `:id` parameter). For multi-param templates read
  `args.pathParams['name']`, not `args.id`.
- `queryParams`: copied from the URI.
- `isFromDeeplink: true`.
- `args.object` carries the ORIGINAL incoming `Uri` (before normalization);
  apps use it for analytics/handlers.
- Effective `pushGlobally` for the navigation comes from the route's resolved
  `deepLinkPushGlobally` (default true; branch routes force it false, so a
  deep-linked tab lands inside its shell).

## Build-time key conflicts

The generator derives per-route keys: route name + first non-parameter path
segment + every `deepLinkNames` alias. Any key claimed by two routes fails the
build with `RouterBuilderError: Deep-link key conflict(s): 'key' used by A, B`
listing every clash. Fix by renaming the route, changing the path, or editing
`deepLinkNames`. Downgrading to a warning via builder option
`fail_on_conflict: false` keeps the FIRST claimant and silently drops the rest
from `deepLinkMap`; prefer resolving the conflict for real.

## DeepLinkHandler

`deepLinkHandler` on a route is NOT invoked by the matcher. It is a contract
for app code: after a match, the app may call
`match.route.deepLinkHandler?.canHandle(uri)` and `createAction(uri, route)` to
produce a side-effect action (save referral code, queue job) in addition to or
instead of navigating. Large apps often skip per-route handlers entirely and
centralize link side effects in one service; both are valid.

## Worked examples (against the packaged example app)

Route: `details`, `path: '/items/:id'`, `deepLinkNames: ['item', 'product']`,
allowedHosts `['example.com']`.

| Incoming | Normalized | Result |
|---|---|---|
| `https://example.com/items/42` | `/items/42` | Template match; `id = '42'`. |
| `https://shop.example.com/items/42` | `/items/42` | Suffix host accepted; matches. |
| `myapp://items/42` | `/items/42` (host promoted) | Template match. |
| `myapp://item/42` | `/item/42` | No template; alias `item` matches; `id = '42'` (last segment). |
| `myapp://details/42` | `/details/42` | NO match: `details` is the route NAME, not a template segment or alias. |
| `https://evil-example.com/items/42` | `/evil-example.com/items/42` | Host not allowed; host promoted; no match. |

Fix idiom for the name-form link: add the route's own name to its
`deepLinkNames` (`deepLinkNames: ['item', 'product', 'details']`). This never
creates a build-time key conflict with itself, because each route's keys are
collected into a Set before cross-route conflict checking, and the name key
was already claimed by this route. Alternatively change `path` so its first
segment equals the name users link to.

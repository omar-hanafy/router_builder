Score the answer against router_builder's actual semantics:

1. (30%) Conflict handling: recognizes that deep-link keys (route name, first
   non-parameter path segment, every deepLinkNames alias) must be globally
   unique and the build FAILS on conflict by default, so 'item' must be
   REMOVED from the details route in the same change. Answers that keep
   'item' on both routes, or silence the error with fail_on_conflict: false,
   fail this criterion.
2. (30%) Correct declaration shape: RouteInfo('orders', path:
   '/orders/:orderId', ...) with exactly one of builder/child/pageBuilder, and
   policy: RoutePolicy(mustBeAuthorized: true, duplicateBehavior:
   DuplicateRouteBehavior.refresh) - auth must be EXPLICIT because the app
   default is public, and refresh handles the duplicate case.
3. (20%) Reads the order id via args.pathParams['orderId'] (mentions that
   args.id is a last-segment heuristic) somewhere in declaration or prose.
4. (20%) Regeneration: dart run build_runner build (accept mention of the
   legacy --delete-conflicting-outputs flag only if noted as legacy/optional).

Deduct for invented API (isGlobalOnly:, @TypedGoRoute, GoRoute annotations,
route registration calls that do not exist).

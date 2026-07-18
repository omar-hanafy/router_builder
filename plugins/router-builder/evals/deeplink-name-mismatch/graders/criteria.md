Score the answer against router_builder's actual semantics:

1. (40%) Root cause names HOST PROMOTION: for a custom scheme URI the host
   ('details') is promoted to the first path segment, so the URI normalizes to
   /details/42, which matches neither the template '/items/:id' nor the
   aliases ['item', 'product'].
2. (30%) States that the RUNTIME matcher resolves only by path template and
   deepLinkNames aliases; route names (and the generated deepLinkMap) are NOT
   consulted by resolveDeepLink, so "the key is in deepLinkMap" is a red
   herring.
3. (20%) Minimal fix: add 'details' to the route's deepLinkNames (or make the
   path's first segment 'details'); notes this cannot conflict with the
   route's own name key.
4. (10%) Does not invent API (no nonexistent parameters, no claims that
   allowedHosts affects custom schemes, no go_router/auto_route confusion).

Full credit requires 1 and 2. An answer that blames allowedHosts, the
platform link setup, or missing deepLinkMap registration without the above is
wrong (score 0-20%).

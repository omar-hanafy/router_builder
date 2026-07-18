A Flutter app uses router_builder 3.x. QA reports: the web link
https://example.com/items/42 opens the details screen, but the custom scheme
link myapp://details/42 does nothing. The route is declared as:

```dart
@RT()
static const details = RouteInfo(
  'details',
  path: '/items/:id',
  pageBuilder: _detailsPage,
  deepLinkNames: ['item', 'product'],
);
```

Links are delivered to `RoutesHelper.resolveDeepLink(uri, allowedHosts:
['example.com'])`, and QA points out that 'details' appears as a key in
RoutesHelper.deepLinkMap. Explain the exact root cause and give the minimal
fix in the app. Answer in prose; no need to run anything.

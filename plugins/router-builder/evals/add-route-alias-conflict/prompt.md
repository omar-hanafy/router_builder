A Flutter app uses router_builder 3.x with these existing routes (among
others):

```dart
@RT()
static const details = RouteInfo(
  'details',
  path: '/items/:id',
  pageBuilder: _detailsPage,
  deepLinkNames: ['item', 'product'],
);
```

The team asks: "Add an 'orders' route at path /orders/:orderId. Marketing is
repurposing our short links, so the deep link alias 'item' must now ALSO point
at orders. The screen requires login even though our @RTConfig sets
mustBeAuthorized: false app-wide, and opening it twice for the same order
should refresh in place."

Write the exact route declaration you would add, state what else must change
and why, and name the command that regenerates the routes file. Answer in
code + prose; no need to run anything.

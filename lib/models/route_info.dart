import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:router_builder/handlers/deep_link_handler.dart';
import 'package:router_builder/models/route_args.dart';

/// Builder function for creating a localized title for a route.
typedef ScreenTitleBuilder =
    String Function(BuildContext context, [RouteArgs? args]);

/// Builder function for creating route widgets.
typedef ScreenWidgetBuilder =
    Widget Function(BuildContext context, RouteArgs? args);

/// Builder function for creating custom Page objects with transitions.
typedef ScreenPageBuilder =
    Page<dynamic> Function(BuildContext context, RouteArgs? args);

/// The signature of the redirect callback.
typedef RouterRedirect =
    FutureOr<String?> Function(BuildContext context, RouteArgs? args);

/// Defines configuration for a navigation route.
///
/// Routes are the building blocks of your navigation system. They define
/// how screens are built, when redirects occur, and how deep links are handled.
///
/// Use the [@RT] annotation on static RouteInfo fields to include them in
/// code generation.
class RouteInfo extends Equatable {
  /// Creates a standard navigation route.
  ///
  /// Exactly one of [builder], [child], or [pageBuilder] must be provided.
  const RouteInfo(
    this.name, {
    this.title,
    this.builder,
    this.child,
    this.pageBuilder,
    this.isGlobalOnly,
    this.deepLinkAllowed = true,
    this.mustBeAuthorized,
    this.visibleNavBar = true,
    this.redirect,
    this.isPopupRoute,
    this.shouldReplaceAll = false,
    this.isTopLevelOnly = false,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.duplicateBehavior,
    this.policy,
    String? path,
  }) : _path = path,
       isBranch = false,
       branchIndex = null,
       forRedirectionOnly = false,
       branchKey = null,
       branchParentType = null,
       assert(
         (builder != null && child == null && pageBuilder == null) ||
             (builder == null && child != null && pageBuilder == null) ||
             (builder == null && child == null && pageBuilder != null),
         'builder, child, or pageBuilder must be provided.',
       );

  /// Creates a route that only performs redirection.
  ///
  /// Use this for routes that redirect to other routes based on conditions
  /// without displaying their own UI.
  const RouteInfo.redirect(
    this.name, {
    required this.redirect,
    this.title,
    this.isGlobalOnly,
    this.deepLinkAllowed = true,
    this.mustBeAuthorized,
    this.visibleNavBar = true,
    this.isTopLevelOnly = false,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.duplicateBehavior,
    this.policy,
    String? path,
  }) : _path = path,
       forRedirectionOnly = true,
       child = null,
       builder = null,
       pageBuilder = null,
       isBranch = false,
       branchIndex = null,
       branchKey = null,
       branchParentType = null,
       isPopupRoute = false,
       shouldReplaceAll = false;

  /// Creates a route that belongs to a navigation shell (e.g., tab navigation).
  ///
  /// Branch routes are grouped by [branchParentType] and ordered by [branchIndex].
  /// The [branchKey] is used for the branch's Navigator key.
  const RouteInfo.branch(
    this.name, {
    required this.branchIndex,
    required this.branchKey,
    required this.branchParentType,
    this.title,
    this.child,
    this.builder,
    this.pageBuilder,
    this.deepLinkAllowed = true,
    this.mustBeAuthorized,
    this.visibleNavBar = true,
    this.shouldReplaceAll = false,
    this.isTopLevelOnly = false,
    this.deepLinkNames = const [],
    this.deepLinkHandler,
    this.duplicateBehavior,
    this.policy,
    String? path,
  }) : _path = path,
       isBranch = true,
       redirect = null,
       isGlobalOnly = false,
       forRedirectionOnly = false,
       isPopupRoute = false,
       assert(
         (builder != null && child == null && pageBuilder == null) ||
             (builder == null && child != null && pageBuilder == null) ||
             (builder == null && child == null && pageBuilder != null),
         'builder, child, or pageBuilder must be provided.',
       );

  /// Unique identifier for this route.
  final String name;

  /// Whether this route should only be pushed on the root navigator.
  final bool? isGlobalOnly;

  /// Whether this route is used solely for redirections.
  final bool forRedirectionOnly;

  /// Whether this route can be accessed via deep links.
  final bool deepLinkAllowed;

  /// Whether authentication is required to access this route.
  final bool? mustBeAuthorized;

  /// Whether this route belongs to a navigation shell.
  final bool isBranch;

  /// Whether primary navigation UI should remain visible on this route.
  final bool visibleNavBar;

  /// Position of this branch within its shell, if [isBranch] is true.
  final int? branchIndex;

  /// Unique navigator key identifier for branch routes.
  final String? branchKey;

  /// Enum discriminator used to group branch routes.
  final Enum? branchParentType;

  /// Whether this route is presented as a popup or dialog.
  final bool? isPopupRoute;

  /// Whether this route should stay at the top level of its navigator.
  final bool isTopLevelOnly;

  /// Localized title provider for this route.
  ///
  /// Provide a callback that returns the title using the current [BuildContext]
  /// and optional [RouteArgs], e.g. `title: (context, [args]) => context.tr.homeTitle`.
  ///
  /// Because this is a function, it is evaluated at call time and picks up
  /// locale changes during the app session. If omitted, the route has no title.
  final ScreenTitleBuilder? title;

  /// Builds the widget for this route when navigation occurs.
  final ScreenWidgetBuilder? builder;

  /// Static widget instance for routes that do not require a builder.
  final Widget? child;

  /// Builds a custom [Page] for this route, enabling tailored transitions.
  final ScreenPageBuilder? pageBuilder;

  /// Redirect handler for conditional navigation logic.
  final RouterRedirect? redirect;

  /// Backing field for [path]; defaults to `/$name` when `null`.
  final String? _path;

  /// This route will replace all existing routes in the stack when navigated to.
  final bool shouldReplaceAll;

  /// Alternative names for deep link matching.
  final List<String> deepLinkNames;

  /// Handler for complex deep link logic beyond navigation.
  final DeepLinkHandler<dynamic>? deepLinkHandler;

  /// Duplicate behavior override for this route.
  final DuplicateRouteBehavior? duplicateBehavior;

  /// Comprehensive policy for this route.
  final RoutePolicy? policy;

  /// The route's path segment. Defaults to '/$name' if not specified.
  String get path => _path ?? '/$name';

  /// Builds a hierarchical name optionally scoped under [parentRoute].
  String generateName({RouteInfo? parentRoute}) {
    // Use dot notation for hierarchical names
    return parentRoute != null ? '${parentRoute.name}.$name' : name;
  }

  /// Builds a hierarchical path optionally scoped under [parentRoute].
  String generatePath({RouteInfo? parentRoute}) =>
      parentRoute != null ? name : path;

  /// Produces an inspection-friendly map describing this route.
  Map<String, Object?> report() => {
    '$name RouteInfo': {
      'name': name,
      'path': path,
      'isGlobalOnly': isGlobalOnly,
      'forRedirectionOnly': forRedirectionOnly,
      'deepLinkAllowed': deepLinkAllowed,
      'mustBeAuthorized': mustBeAuthorized,
      'isBranch': isBranch,
      'visibleNavBar': visibleNavBar,
      'branchIndex': branchIndex,
      'branchKey': branchKey,
      'isTopLevelOnly': isTopLevelOnly,
      'isPopupRoute': isPopupRoute,
      'title': title,
      'builder': builder,
      'child': child,
      'pageBuilder': pageBuilder,
      'redirect': redirect,
      'deepLinkNames': deepLinkNames,
      'deepLinkHandler': deepLinkHandler,
      'duplicateBehavior': duplicateBehavior,
      'policy': policy,
    },
  };

  /// Fields used by [Equatable] for equality checks.
  @override
  List<Object?> get props => [
    name,
    isGlobalOnly,
    forRedirectionOnly,
    deepLinkAllowed,
    mustBeAuthorized,
    isBranch,
    branchIndex,
    branchKey,
    path,
    isPopupRoute,
    isTopLevelOnly,
    duplicateBehavior,
    policy,
  ];
}

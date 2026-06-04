# CHANGELOG

## 1.3.0 - 2026-06-04

Bump dart_helper_utils constraint to ^6.x

## 1.2.0 - 2026-01-20

### 🚀 Major Feature: Policy-Driven Routing

This release introduces a robust, hierarchical configuration system for route behaviors, allowing precise control over authorization, duplication, and global navigation settings.

#### Added
- **RoutePolicy**: Centralized policy object for `mustBeAuthorized`, `duplicateBehavior`, `pushGlobally`, and `isPopupRoute`.
- **Global Defaults**: New `RouterBuilderConfig` to set app-wide default policies.
- **Duplicate Route Control**: Added `DuplicateRouteBehavior` to `RouteInfo` and `RouteArgs`.
- **Precedence Logic**: `RouteArgs` now resolves policies in a clear order:
  1. Args Override
  2. Args Policy
  3. Route Definition Override
  4. Route Definition Policy
  5. Global Defaults

#### Updated
- **RouteInfo**: Added `duplicateBehavior` and `policy` fields.
- **RouteArgs**: Added override fields (`duplicateBehavior`, `mustBeAuthorized`, `policy`) and logic to compute effective values.
- **Code Generator**: Updated to support `duplicateBehavior` in `@RT` annotations.

## 1.1.2 - 2025-11-07
- Renamed `replaceAll` to `shouldReplaceAll`.

## 1.1.1 - 2025-10-24
- Documented all public APIs.

## 1.1.0 - 2025-10-24
- Updated exports.

## 1.0.0 - 2025-01-24

### 🚀 Major Enhancement: Unified Deep Link System

#### Added
- **DeepLinkHandler<T>**: New generic abstract class for type-safe deep link handling
- **Enhanced RouteInfo**: Added `deepLinkHandler` parameter to all RouteInfo constructors
- **Comprehensive Deep Link Map**: Generated map now includes:
  - Route names as keys
  - First path segments as keys  
  - Deep link aliases from `deepLinkNames`
  - Build-time conflict detection with detailed error messages
- **Migration Guide**: Comprehensive guide for migrating from separate deep link registries
- **Updated Documentation**: Enhanced AI docs with deep link examples and patterns

#### Changed
- **Code Generator**: Enhanced to extract path parameters and create comprehensive key mappings
- **Deep Link Resolution**: Routes are now the single source of truth for deep links
- **Generated Helper**: `deepLinkMap` is now suitable for complete URI resolution

#### Benefits
- ✅ Single source of truth for routes and deep links
- ✅ No more RegExp patterns or manual handler registration
- ✅ Build-time validation of deep link conflicts
- ✅ Co-located deep link logic with route definitions
- ✅ Reduced boilerplate code
- ✅ Type-safe deep link handling

## 0.0.1 - Initial Release

- **INITIAL**: Initial release with basic route generation
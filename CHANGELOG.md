# CHANGELOG

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

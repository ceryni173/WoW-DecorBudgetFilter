# Changelog

All notable changes to DecorBudgetFilter will be documented in this file.

## [0.4.1] - 2025-02-13

### Fixed
- Simplified cache to use basic eviction (clears at 500 items) instead of buggy LRU implementation
- Removed broken API fallback code that would error if executed
- Removed unnecessary security theater comments
- Code cleanup and simplification

### Changed
- Streamlined GetCostFromEntryInfo to only use direct placementCost field
- Simplified cache statistics display
- Reduced overall code complexity

## [0.4.0] - 2025-02-12

### Added
- Live item count display showing "Showing X/Y items"
- Enhanced visual styling with color-coded budget tiers
  - Budget 1: Light green
  - Budget 3: Gold
  - Budget 5: Light red
- Improved tooltip with detailed usage instructions
- Right-click dropdown to instantly clear filter
- Performance optimizations:
  - Smart caching system (500 item cache)
  - Debounced filter application (50ms delay)
  - Automatic cache cleanup on memory limits

### Changed
- Repositioned dropdown to float above main content area
- Enhanced budget label to always show current selection
- Improved "Show Unknown Cost" toggle with visual checkmark
- Better separation in dropdown menu

### Fixed
- Filter now properly updates when switching between categories
- Cache no longer grows unbounded
- Reduced UI lag when toggling filters rapidly

## [0.3.0] - Previous Version

### Added
- Basic budget filtering functionality
- Dropdown UI integration
- Slash commands `/decorbudget` and `/dbf`
- SavedVariables persistence
- Debug mode

### Changed
- Initial implementation of filter logic

## [0.2.0] - Early Development

### Added
- Core filtering mechanism
- API wrapper functions
- ScrollBox detection

## [0.1.0] - Initial Release

### Added
- Basic addon structure
- TOC file
- Initial proof of concept

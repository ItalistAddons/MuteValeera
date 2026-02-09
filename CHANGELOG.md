# Changelog

All notable changes to this project will be documented in this file.

## [1.4.0] - 2026-02-09

### Added
- In-game Settings panel with custom sound ID management
- Clickable labels on checkboxes for better UX
- Visual custom sound ID list with individual remove buttons
- Export/Import functionality via popup dialogs
- `list` command to show all custom IDs
- Locale-independent tooltip detection using NPC IDs
- Space-separated input support for multi-ID commands

### Fixed
- Settings panel now properly saves checkbox states
- `validate` command correctly handles hash table custom list
- Settings panel no longer shows unrelated WoW options
- Removed dead code after `clearconfirm` wipe
- `ApplyMuteState` no longer called for read-only commands
- TOC Interface version updated to 120001 (Midnight ready)

### Changed
- Switched from `RegisterVerticalLayoutCategory` to `RegisterCanvasLayoutCategory`
- Deep-copy `DEFAULTS.customList` during migration to prevent reference sharing
- Settings panel shows inline descriptions instead of tooltips
- Improved help text formatting and accuracy
- Full input string now captured for multi-argument commands

## [1.3.5] - Previous Release

### Added
- Initial release with basic muting functionality
- Slash command interface
- Custom sound ID support
- Critical line filtering

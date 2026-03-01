# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- Relaxed the built-in Valeera audit rule to include audited `vo_120` companion files from Wago Tools pages `9` through `15` when they were updated after build `12.0.0.63534`
- Added `150` verified Valeera file data IDs to the default mute list; each entry was first seen in `12.0.0.63534` and updated in `12.0.0.64499`
- Enabled CurseForge publishing for project ID `1475450` in the tag-driven release pipeline

## [1.0.0] - 2026-03-01

### Added
- Initial public release of `MuteValeera`, cloned from the `MuteRepetitiveBrann` addon architecture
- Valeera branding, slash commands, settings panel text, and SavedVariables retargeted to the new addon
- Midnight-compatible packaging, CI, and tag-driven GitHub release automation

### Changed
- The built-in mute list is intentionally empty in this first release
- Candidate Valeera files were audited from Wago Tools search pages `9` through `15` and filtered against the rule `first version > 12.0.0.63534`
- No Valeera delve-companion voice assets met that exact inclusion rule, so the addon ships with verified behavior but no default muted IDs yet

### Compatibility
- Retail Midnight compatible (`## Interface: 120001`)
- Existing `MuteValeeraSettings` are preserved across updates
- Tooltip augmentation is disabled by default until Valeera companion NPC IDs are confirmed safely

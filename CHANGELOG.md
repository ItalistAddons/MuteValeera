# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-04-11

### Added
- **Dundun mute** — 39 verified voice-line IDs (`dundun_rat` companion VO + `vo_1200_dundun` Abundance-event VO, builds `12.0.0.63534` and `12.0.0.64741`) added as an individually toggled mute list, enabled by default
- **Nanea mute** — 33 verified voice-line IDs (Loa Speaker Nanea Revantusk — Nalorakk's Den, builds `12.0.0.63534`, `12.0.0.63854`, and `12.0.0.64741`) added as an individually toggled mute list, enabled by default
- Slash sub-commands `/mutevaleera dundun on|off|toggle|status` and `/mutevaleera nanea on|off|toggle|status`
- Per-NPC checkboxes in the settings UI for Dundun and Nanea
- Optional speech bubble suppression for Valeera, enabled by default alongside voice muting
- New `/mutevaleera bubbles on|off|toggle|status` slash commands and matching settings panel checkbox

### Changed
- Settings version migration no longer prints a chat message on login, reload, or zone changes
- `/mutevaleera status` now reports Dundun and Nanea mute state, speech bubble status, active strategy, and delve state
- Bubble suppression now prefers locale-independent Valeera-only hiding when the client exposes stable bubble ownership metadata
- When selective bubble ownership data is unavailable, the addon falls back to hiding world chat bubbles only while the player is confirmed to be inside a delve and restores the prior CVar afterward

## [1.0.2] - 2026-03-02

### Fixed
- Removed the tooltip status logic entirely, avoiding tooltip taint from GUID inspection on modern clients

## [1.0.1] - 2026-03-02

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

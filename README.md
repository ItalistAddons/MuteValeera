# Mute Valeera

Silences Valeera Sanguinar's repetitive delve companion voice lines in World of Warcraft, using the same single-file addon architecture as `MuteRepetitiveBrann`.

## Features

- **Selective Muting**: Choose between partial mute and full mute
- **Custom Sound IDs**: Add your own sound IDs beyond the built-in Valeera list
- **In-Game Settings Panel**: Open the Blizzard settings category with `/mutevaleera ui`
- **Slash Commands**: Full command-line control for power users
- **Locale-Independent**: Works in all WoW client languages
- **Import/Export**: Share custom sound ID lists with friends

## Installation

1. Download a packaged release from [GitHub Releases](https://github.com/ItalistAddons/MuteValeera/releases)
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or `/reload`

## Compatibility

- Retail Midnight compatible (`## Interface: 120001`)
- Existing `MuteValeeraSettings` are preserved
- If the client no longer exposes the sound mute API, the addon warns once and disables muting instead of throwing Lua errors

## Default Scope

- The built-in mute list is limited to Valeera Sanguinar delve-companion voice assets first introduced after build `12.0.0.63534`
- The initial candidate pool is the Wago Tools `Valeera` file search on pages `9` through `15`
- That exact audit did not produce any files that met the rule `first version > 12.0.0.63534`
- As a result, `1.0.0` ships with an empty built-in mute list and relies on the custom sound-ID workflow until verified post-`63534` Valeera lines are confirmed

## Commands

### Basic

- `/mutevaleera` or `/mv` - Show help
- `/mutevaleera on` - Enable muting
- `/mutevaleera off` - Disable muting
- `/mutevaleera toggle` - Toggle mute state
- `/mutevaleera full` - Mute critical lines too
- `/mutevaleera partial` - Allow critical lines
- `/mutevaleera status` - Show current settings
- `/mutevaleera ui` - Open settings panel

### Custom Sound IDs

- `/mutevaleera add <ids>` - Add custom sound IDs (comma/space-separated)
- `/mutevaleera del <ids>` - Remove custom sound IDs
- `/mutevaleera list` - Show all custom sound IDs
- `/mutevaleera clear` - Clear all custom IDs (requires confirmation)
- `/mutevaleera validate` - Check custom IDs for issues

### Advanced

- `/mutevaleera export` - Copy custom IDs for backup/sharing
- `/mutevaleera import <ids>` - Import custom IDs from string
- `/mutevaleera helpfull` - Detailed command help

## Examples

```text
/mv on
/mutevaleera add 12345,67890
/mutevaleera add 111 222 333
/mv full
/mutevaleera export
```

## Release Process

- Releases are tag-driven and automated
- Pushing a tag that matches `v*` triggers GitHub Actions packaging and a GitHub release
- This repository currently publishes GitHub releases only; CurseForge publishing is intentionally disabled until a real project exists
- Never commit tokens or place credentials in source files, tracked docs, issues, pull requests, or local config intended for commit
- Local Windows dry-run packaging should use the official packager wrapper in `package.ps1`; see `PUBLISHING.md` for prerequisites and troubleshooting

## Contributing

- Contributor guidance: [CONTRIBUTING.md](CONTRIBUTING.md)
- Publishing and Windows troubleshooting: [PUBLISHING.md](PUBLISHING.md)

## Support

- **Issues**: [GitHub Issues](https://github.com/ItalistAddons/MuteValeera/issues)
- **Releases**: [GitHub Releases](https://github.com/ItalistAddons/MuteValeera/releases)

## License

All Rights Reserved (c) 2024-2026 Italist

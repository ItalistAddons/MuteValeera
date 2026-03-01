# Mute Repetitive Brann

Silences Brann Bronzebeard's repetitive voice lines during delves and adventures in World of Warcraft: The War Within and beyond.

## Features

- **Selective Muting**: Choose between partial mute (allows critical gameplay warnings) or full mute
- **Custom Sound IDs**: Add your own sound IDs to mute beyond Brann
- **In-Game Settings Panel**: Easy-to-use interface accessible via `/mutebrann ui`
- **Slash Commands**: Full command-line control for power users
- **Locale-Independent**: Works in all WoW client languages
- **Import/Export**: Share custom sound ID lists with friends

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/mute-repetitive-brann)
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or `/reload`

## Compatibility

- Retail Midnight compatible (`## Interface: 120001`)
- Existing SavedVariables are preserved
- If the client no longer exposes the sound mute API, the addon warns once and disables muting instead of throwing Lua errors

## Commands

### Basic

- `/mutebrann` or `/mb` - Show help
- `/mutebrann on` - Enable muting
- `/mutebrann off` - Disable muting
- `/mutebrann toggle` - Toggle mute state
- `/mutebrann full` - Mute critical lines too
- `/mutebrann partial` - Allow critical lines
- `/mutebrann status` - Show current settings
- `/mutebrann ui` - Open settings panel

### Custom Sound IDs

- `/mutebrann add <ids>` - Add custom sound IDs (comma/space-separated)
- `/mutebrann del <ids>` - Remove custom sound IDs
- `/mutebrann list` - Show all custom sound IDs
- `/mutebrann clear` - Clear all custom IDs (requires confirmation)
- `/mutebrann validate` - Check custom IDs for issues

### Advanced

- `/mutebrann export` - Copy custom IDs for backup/sharing
- `/mutebrann import <ids>` - Import custom IDs from string
- `/mutebrann helpfull` - Detailed command help

## Examples

```text
/mb on
/mutebrann add 12345,67890
/mutebrann add 111 222 333
/mb full
/mutebrann export
```

## Release Process

- Releases are tag-driven and automated.
- Pushing a tag that matches `v*` triggers GitHub Actions packaging and publishing.
- CurseForge publishing uses the GitHub Actions repository secret `CF_API_KEY`.
- Never commit tokens or place CurseForge credentials in source files, tracked docs, issues, pull requests, or local config intended for commit.
- Local Windows dry-run packaging should use the official packager wrapper in `package.ps1`. See `PUBLISHING.md` for prerequisites and troubleshooting.

## Contributing

- Contributor guidance: [CONTRIBUTING.md](CONTRIBUTING.md)
- Publishing and Windows troubleshooting: [PUBLISHING.md](PUBLISHING.md)

## Support

- **Issues**: [GitHub Issues](https://github.com/ItalistAddons/MuteRepetitiveBrann/issues)
- **CurseForge**: [Project Page](https://www.curseforge.com/wow/addons/mute-repetitive-brann)

## License

All Rights Reserved (c) 2024-2026 Italist

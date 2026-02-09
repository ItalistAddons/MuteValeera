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

```
/mb on
/mutebrann add 12345,67890
/mutebrann add 111 222 333
/mb full
/mutebrann export
```

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/MuteRepetitiveBrann/issues)
- **CurseForge**: [Project Page](https://www.curseforge.com/wow/addons/mute-repetitive-brann)

## License

All Rights Reserved © 2024-2026 Italist

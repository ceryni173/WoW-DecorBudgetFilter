# DecorBudgetFilter

> A World of Warcraft addon that adds placement budget filtering to the Housing Storage catalog

[![CurseForge](https://img.shields.io/badge/CurseForge-DecorBudgetFilter-orange)](https://www.curseforge.com/wow/addons/decorbudgetfilter)


## Installation

### Automatic (Recommended)
Install via Curse Forge:
- [CurseForge App](https://www.curseforge.com/)

### Manual
1. Download the latest release
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or reload UI (`/reload`)

## Usage

### Via Dropdown UI
1. Open the Housing Editor
2. Go to the Storage panel
3. Use the "Budget" dropdown in the top-right corner
4. Select your desired budget filter (All, 1, 3, or 5)
5. **Pro tip:** Right-click the dropdown to quickly clear the filter

### Via Slash Commands
```
/decorbudget [all|1|3|5]
/dbf [all|1|3|5]
```

**Examples:**
```
/decorbudget 1        → Show only budget 1 items
/decorbudget all      → Show all items
/decorbudget help     → Display help
/decorbudget debug    → Toggle debug mode
/decorbudget reset    → Reset all settings
```

## Settings

- **Budget Filter:** Choose which placement cost tier to display
- **Show Unknown Cost:** Toggle whether items with unknown costs should be shown
- **Debug Mode:** Enable detailed logging (use `/decorbudget debug`)

## FAQ

**Q: What do the budget numbers mean?**
A: The budget numbers (1, 3, 5) represent the placement cost of each decor item when placed in your house. Items with lower costs let you place more decorations within your budget limit.

**Q: Why are some items showing as "unknown cost"?**
A: Some items may not have placement cost data available yet, or the API structure changed. Use the "Show Unknown Cost" toggle to control their visibility.

**Q: Does this work with other housing addons?**
A: Yes! DecorBudgetFilter is designed to work alongside other housing addons without conflicts.

**Q: Will this work in future patches?**
A: The addon is built with multiple fallback paths to handle API changes, making it resilient to future updates.

## Support

- **Issues:** [GitHub Issues](https://github.com/ceryni173/WoW-DecorBudgetFilter/issues)
- **CurseForge:** [Project Page](https://www.curseforge.com/wow/addons/decorbudgetfilter)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Author

**Ceryni-Moonglade**

## License

All Rights Reserved

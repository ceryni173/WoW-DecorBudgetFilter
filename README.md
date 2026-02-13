# DecorBudgetFilter

> A World of Warcraft addon that adds placement budget filtering to the Housing catalog

[![CurseForge](https://img.shields.io/badge/CurseForge-DecorBudgetFilter-orange)](https://www.curseforge.com/wow/addons/decor-budget-filter)


## Installation

### Automatic (Recommended)
Install via CurseForge:
- [CurseForge App](https://www.curseforge.com/)

### Manual
1. Download the latest release
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or reload UI (`/reload`)

## Usage

### Via Dropdown UI
1. Open the Housing Dashboard (Catalog tab) or the House Editor Storage panel
2. Use the "All Costs" dropdown between the search bar and the Filter button
3. Select your desired budget filter (All Costs, Budget 1, Budget 3, or Budget 5)

### Via Slash Commands
```
/dbf [all|1|3|5|debug]
/decorbudget [all|1|3|5|debug]
```

**Examples:**
```
/dbf 1        Show only budget 1 items
/dbf 3        Show only budget 3 items
/dbf all      Show all items (clear filter)
/dbf debug    Toggle debug output
/dbf          Display help
```

## FAQ

**Q: What do the budget numbers mean?**
A: The budget numbers (1, 3, 5) represent the placement cost of each decor item when placed in your house. Items with lower costs let you place more decorations within your budget limit.

**Q: Does this work with other housing addons?**
A: Yes. DecorBudgetFilter hooks into Blizzard's data pipeline (filtering entry lists before they reach the ScrollBox) rather than manipulating UI frames directly, so it should not conflict with other housing addons.

**Q: Does this work in both the Dashboard and the in-house editor?**
A: Yes. The filter applies to both the Housing Dashboard catalog and the House Editor Storage panel.

## Support

- **Issues:** [GitHub Issues](https://github.com/ceryni173/WoW-DecorBudgetFilter/issues)
- **CurseForge:** [Project Page](https://www.curseforge.com/wow/addons/decor-budget-filter)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Author

**Ceryni-Moonglade**

## License

All Rights Reserved

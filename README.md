# ✨ StatSparkle

**Watch your stats move, live.** StatSparkle is a World of Warcraft addon that shows your primary stat, Armor and secondary stats in a glowing neon panel. It works for every class and spec. When a trinket, proc or buff pushes a stat up or down, its row lights up **green** or **red**, an arrow bobs next to it, the exact change is shown, and a burst of cartoon stars pops out. If a stat climbs really high, it goes **supernova**.

![StatSparkle preview](docs/preview.png)

*Protection spec: Strength and Haste are up from procs, Critical Strike is down, and the rest are at your normal values.*

![StatSparkle in game: Strength and Intellect](docs/ingame.png)

*In game: Strength on a Protection Paladin (left), Intellect after changing to Holy (right).*

---

## What it shows

| Stat | Colour | Shown as |
|---|---|---|
| 🔨 **Strength** / 🗡️ **Agility** / 📖 **Intellect** (primary) | Orange / Pink / Blue | Whole number, e.g. `48,912` |
| 🛡️ **Armor** | Silver | Whole number |
| 🔥 **Critical Strike** | Fiery red | Percentage |
| ⚡ **Haste** | Golden yellow | Percentage |
| 💜 **Mastery** | Purple | Percentage |
| 💠 **Versatility** | Teal | Percentage |

## One addon for every class

The top row always shows the primary stat that **your current spec** uses:

| Primary stat | Specs |
|---|---|
| 🔨 **Strength** | Warriors, Death Knights, Protection and Retribution Paladins |
| 🗡️ **Agility** | Rogues, Hunters, Havoc and Vengeance Demon Hunters, Feral and Guardian Druids, Brewmaster and Windwalker Monks, Enhancement Shamans |
| 📖 **Intellect** | Mages, Priests, Warlocks, Evokers, Holy Paladins, Balance and Restoration Druids, Elemental and Restoration Shamans, Mistweaver Monks, Devourer Demon Hunters |

When you change spec, only that row swaps to the new stat's colour, icon and lettering. The other rows stay as they are, and StatSparkle learns your normal stats again for the new spec.

![The Strength, Agility and Intellect rows](docs/primary_rows.png)

## 💥 Supernova

When a percentage stat reaches **60% or higher**, its number turns white-hot and the row explodes like a star: shockwave rings, spinning light rays, a flash, sparks and a little screen shake. It keeps getting wilder all the way up to 90%.

![StatSparkle supernova](docs/preview_supernova.png)

*Holy spec, with Haste gone supernova at 74.60%.*

## Features

- **Live updates.** Numbers change the moment a buff, proc, trinket or debuff affects you.
- **Green and red highlights.** A row glows green with an ▲ arrow when the stat is above your normal value, and red with a ▼ arrow when it's below. The change (`+6.00%`, `-1,240`) is shown under the stat name.
- **Sparkle effects.** Star bursts, a light sweep across the row, and glowing numbers that hop when a stat jumps. Stars and ghost arrows keep floating up while it stays raised.
- **Smart "normal" baseline.** StatSparkle learns your normal stats while you're out of combat and nothing is changing. It never updates during combat, so a long cooldown (like Avenging Wrath) can't be mistaken for "normal" and show a false drop afterwards. The baseline resets automatically when you change gear, spec or talents.
- **Correct crit for your spec.** Uses spell crit for Intellect specs, and melee or ranged crit for Strength and Agility specs.
- **Movable and resizable.** Drag it anywhere and scale it to fit your UI.
- **Optional sparkle sound** when stats change (off by default).

## Slash commands

| Command | What it does |
|---|---|
| `/ss` | Show help |
| `/ss test` | Fake one proc up and one proc down to see the effects |
| `/ss nova` | Fake a Haste supernova |
| `/ss nova 55` | Make supernova start at 55% (default 60) |
| `/ss nova off` | Turn the supernova effect off (`/ss nova on` to turn it back on) |
| `/ss unlock` | Unlock the panel so you can drag it |
| `/ss lock` | Lock it in place |
| `/ss scale 1.2` | Resize (0.3 to 3) |
| `/ss normal` | Treat your current stats as normal (resets the baseline) |
| `/ss sound` | Toggle the sparkle sound |
| `/ss reset` | Reset position, scale and settings |

`/statsparkle` works too.

## Installation

**CurseForge app:** search for **StatSparkle** and click Install.

**Manual:**
1. Download the latest release zip.
2. Extract it so the `StatSparkle` folder ends up at
   `World of Warcraft/_retail_/Interface/AddOns/StatSparkle/`
3. Restart the game or type `/reload`.

## Artwork

All textures are hand-made for this addon:

![StatSparkle textures](docs/textures.png)

## Credits

- Font: [Poppins](https://fonts.google.com/specimen/Poppins), used under the SIL Open Font License

## Author

Made by Orion ([rlucas2100](https://github.com/rlucas2100)).

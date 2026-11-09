# ✨ StatSparkle

**Watch your stats move, live.** StatSparkle shows your primary stat, Armor and secondary stats in a glowing neon panel. When a trinket, proc or buff pushes a stat up or down, its row lights up **green** or **red**, an arrow bobs next to it and tiny cartoon stars pour out beside the number. When a stat climbs to **50%** and well above your normal, it goes into golden **jackpot mode** with crackling lightning and a rainbow phoenix arrow. At **60%** it goes **supernova**.

**Works for every class and spec, in and out of combat.** Strength, Agility or Intellect: StatSparkle shows the one your spec uses, and switches by itself when you change spec.

![StatSparkle in game: Strength and Intellect](https://raw.githubusercontent.com/rlucas2100/Stat_sparkle_wow/main/docs/ingame.png)

*In game: Strength on a Protection Paladin (left), Intellect after changing to Holy (right).*

---

## 🗡️ Strength, Agility or Intellect: picked for you

The top row always shows the primary stat that **your current spec** uses. You don't need a separate version for casters, healers, tanks or melee.

![The Strength, Agility and Intellect rows](https://raw.githubusercontent.com/rlucas2100/Stat_sparkle_wow/main/docs/primary_rows.png)

| Primary stat | Colour | Specs |
|---|---|---|
| 🔨 **Strength** | Orange | Warriors, Death Knights, Protection and Retribution Paladins |
| 🗡️ **Agility** | Pink | Rogues, Hunters, Havoc and Vengeance Demon Hunters, Feral and Guardian Druids, Brewmaster and Windwalker Monks, Enhancement Shamans |
| 📖 **Intellect** | Blue | Mages, Priests, Warlocks, Evokers, Holy Paladins, Balance and Restoration Druids, Elemental and Restoration Shamans, Mistweaver Monks, Devourer Demon Hunters |

**Changing spec:** only the primary stat row changes. It swaps to the new stat's colour, icon and lettering with a little burst of stars. The other rows stay as they are, and StatSparkle learns your normal stats again for the new spec. It also follows you when you swap talent loadouts or log in on another character.

**Crit is right for your spec too.** Intellect specs see spell crit. Strength and Agility specs see melee or ranged crit.

---

## What it shows

| Stat | Colour | Shown as |
|---|---|---|
| 🔨 Strength / 🗡️ Agility / 📖 Intellect | Orange / Pink / Blue | Whole number, e.g. `48,912` |
| 🛡️ **Armor** | Silver | Whole number |
| 🔥 **Critical Strike** | Fiery red | Percentage |
| ⚡ **Haste** | Golden yellow | Percentage |
| 💜 **Mastery** | Purple | Percentage |
| 💠 **Versatility** | Teal | Percentage |

![StatSparkle with procs up and down](https://raw.githubusercontent.com/rlucas2100/Stat_sparkle_wow/main/docs/preview.png)

*Strength and Haste are up from procs, Critical Strike is down, and the rest are at your normal values.*

## ⭐ Stars while a stat is up

While a stat is up, tiny cartoon stars in green, gold and white pour out to the left and right of the number. They stay inside the row and never cover the number.

## 🎰 Jackpot mode at 50%

When Critical Strike, Haste, Mastery or Versatility reaches **50% or more** and is at least **5% above your normal**, the row goes into jackpot mode. It's gold, so it stands apart from rows that are just green, and from red, which means a stat is down:

- a deep purple aura and a gold ring that shimmers between gold and orange
- purple and gold lightning crackling across the row, behind the number
- a number that shifts between gold and orange
- a rainbow phoenix arrow that flashes through every colour, glowing in a rainbow orb, with sparkles spraying off its tips
- stars in every colour pouring out either side

![StatSparkle jackpot mode](https://raw.githubusercontent.com/rlucas2100/Stat_sparkle_wow/main/docs/ingame_jackpot.png)

*Critical Strike at 52.23% in jackpot mode, with its gold number and rainbow phoenix arrow. Armor, Haste and Mastery are up from procs.*

Jackpot mode starts 10% below the supernova point, so `/ss nova 55` moves it to 45%.

The 5% rule means a stat that's always around 50%, like a Holy Paladin's Mastery, doesn't sit in jackpot mode all the time. It lights up when a proc or buff pushes it higher.

Out of combat you also hear a short shimmer as a stat goes into jackpot mode. It's the only sound StatSparkle makes, so it won't clash with your other addons. `/ss sound` turns it off.

## ⚔️ In combat

World of Warcraft: Midnight hides your exact stats from addons during combat. StatSparkle still shows the live numbers, and rows still light up green or red with the arrow, the stars, jackpot mode and the supernova. It lets the game do the comparison.

A few things only work out of combat: the exact change under the stat name (`+6.00%`), the star burst at the moment of a proc, the supernova's flash and screen shake, and the jackpot sound. Type `/ss combat` to preview the in-combat look.

![StatSparkle in combat](https://raw.githubusercontent.com/rlucas2100/Stat_sparkle_wow/main/docs/ingame_combat.png)

*In combat on a Protection Paladin: Strength, Armor and Haste are up from procs, and Critical Strike has hit 60.50% and gone supernova.*

## 💥 Supernova

When a percentage stat reaches **60% or higher**, its number turns white-hot and the row explodes like a star: shockwave rings, spinning light rays, a flash, sparks and a little screen shake. It keeps getting wilder all the way up to 90%. In combat you still get the white-hot glow, the light rays and the shockwave rings.

![StatSparkle supernova](https://raw.githubusercontent.com/rlucas2100/Stat_sparkle_wow/main/docs/preview_supernova.png)

*An Intellect spec with Haste gone supernova at 74.60%.*

## Features

- **Live updates.** Numbers change the moment a buff, proc, trinket or debuff affects you.
- **Green and red highlights, in and out of combat.** A row glows green with an ▲ arrow when the stat is above your normal value, and red with a ▼ arrow when it's below. Out of combat, the change (`+6.00%`, `-1,240`) is shown under the stat name.
- **Sparkle effects.** Tiny cartoon stars pour out beside a number while it's up. Out of combat you also get star bursts, a light sweep and a hop when a stat jumps.
- **Smart "normal" baseline.** StatSparkle learns your normal stats while you're out of combat and nothing is changing. It never updates during combat, so a long cooldown can't be mistaken for "normal" and show a false drop afterwards. It starts over when you change gear, spec or talents.
- **Movable and resizable.** Drag it anywhere and scale it to fit your UI.
- **One gentle sound:** a shimmer when a stat goes into jackpot mode out of combat. Nothing else makes a sound.

## Slash commands

| Command | What it does |
|---|---|
| `/ss` | Show help |
| `/ss test` | Fake one proc up and one proc down to see the effects |
| `/ss combat` | Preview the in-combat look for 8 seconds |
| `/ss nova` | Fake a Haste supernova |
| `/ss nova 55` | Make supernova start at 55% (default 60). Jackpot mode starts 10% below that. |
| `/ss nova off` | Turn the supernova effect off (`/ss nova on` to turn it back on) |
| `/ss unlock` | Unlock the panel so you can drag it |
| `/ss lock` | Lock it in place |
| `/ss scale 1.2` | Resize (0.3 to 3) |
| `/ss normal` | Treat your current stats as normal |
| `/ss sound` | Turn the jackpot shimmer sound off or on |
| `/ss reset` | Reset position, scale and settings |

`/statsparkle` works too.

## Installing by hand

With the CurseForge app, just click Install. If you download the zip yourself, open it and drag the `StatSparkle` folder inside it into `World of Warcraft/_retail_/Interface/AddOns/`. You should end up with `AddOns/StatSparkle/StatSparkle.toc`. If you use Windows' **Extract All**, change the destination to the `AddOns` folder itself, or Windows adds an extra folder and WoW won't find the addon. Then restart the game.

## FAQ

**Do I need a different version for my caster, healer or rogue?**
No. There is one StatSparkle for everyone. It reads your spec and shows Strength, Agility or Intellect to match.

**A row lit up right after I changed spec or gear. Why?**
Some passives take a moment to apply after a change. StatSparkle settles on your new normal stats once you're out of combat and nothing has changed for a few seconds. Type `/ss normal` to accept your current stats straight away.

**Why don't I see the `+6.00%` change line in combat?**
World of Warcraft: Midnight hides your exact stats from addons during combat, so StatSparkle can't work out the difference. The row still lights up, and the change line comes back as soon as combat ends.

**Can I see the panel without waiting for a proc?**
Type `/ss test` for an up and a down, `/ss combat` for the in-combat look, or `/ss nova` for a supernova.

---

Source code and full changelog: [github.com/rlucas2100/Stat_sparkle_wow](https://github.com/rlucas2100/Stat_sparkle_wow)

Font: [Poppins](https://fonts.google.com/specimen/Poppins), used under the SIL Open Font License.

## Author

Made by Orion ([rlucas2100](https://github.com/rlucas2100)).

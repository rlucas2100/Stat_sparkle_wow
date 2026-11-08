# StatSparkle Changelog

## 2.10.1

### Changed
- **🎰 Fire mode is now golden jackpot mode.** At 50% or more, the row's ring, number and arrow shimmer between gold and orange instead of purple and orange. The old colours could look red, and red should only ever mean a stat has dropped. The purple aura, the purple and gold lightning, and the rainbow stars are still there.

### Fixed
- **Red now works in combat too.** When a stat dropped below your normal during a fight, for example while an effect turned your secondary stats into Strength, its row stayed plain instead of turning red. Now it turns red with the ▼ arrow in combat too. StatSparkle checks how the game draws its bars when you log in and picks a method that works. If it can't tell, red stays off in combat, so a row never turns red by mistake.
- `/ss combat` now also tells you whether red works in combat.

---

## 2.10.0

### New
- **⚔️ Highlights now work in combat.** World of Warcraft: Midnight hides your exact stats from addons during combat, so rows used to stay plain while you fought. Now they still light up **green** or **red** with the bobbing arrow, and the stars, fire mode and the supernova all work in combat too. StatSparkle lets the game do the comparison.
- **⭐ Tiny cartoon stars.** While a stat is up, little green, gold and white stars pour out to the left and right of the number. They stay inside the row and never cover the number.
- **🔥 Fire mode at 50%.** When Critical Strike, Haste, Mastery or Versatility reaches 50% or more, the row turns purple and orange so it stands apart from plain green rows. It gets a deep purple aura, a fiery ring, lightning crackling behind the number (from Juggernaut Mode), a fiery number and arrow, and stars in every colour. It starts 10% below the supernova point, so `/ss nova` moves it too.
- **A shimmer sound at 50%.** Out of combat, a short shimmer plays when a stat climbs past 50%. `/ss sound` turns it off or on.
- **`/ss combat`** previews the in-combat look for 8 seconds.

### Changed
- **One sound only.** The old optional "sparkle on every change" sound is gone. The 50% shimmer is the only sound left, so StatSparkle won't clash with your other addons' sounds.
- Numbers keep their thousands separators in combat (`3,873`).
- The supernova keeps the number readable in combat.

### Fixed
- Critical Strike no longer shows a false drop or rise in combat. It used to switch to a different kind of crit reading when the numbers were hidden.
- A number no longer stays green or red from before combat once the fight starts.

---

## 2.9.0

### New
- **🗡️ Agility support. StatSparkle now works for every class and spec.** The primary stat row shows Strength, Agility or Intellect, whichever your current spec uses. Agility has its own rose-pink row, dagger icon and lettering.
- Change spec and only the primary stat row swaps. The rest of the panel stays as it is.

### Changed
- The primary stat is read straight from your spec. If the game can't tell StatSparkle yet (for example on a loading screen), it falls back to a built-in list of specs, then to whichever of Strength, Agility or Intellect is highest on your gear.
- Strength and Agility specs both use melee or ranged crit. Intellect specs use spell crit.

---

## 2.8.0

### New
- **💥 Supernova!** When a percentage stat reaches **60% or higher**, its number turns white-hot and the row goes off like an exploding star: shockwave rings, spinning light rays, a flash, sparks and a little screen shake. It keeps getting wilder all the way up to 90%, and the row starts to warm up as it gets close.
- **Intellect support for Holy.** The primary stat row now follows your spec: Strength for Protection and Retribution, Intellect for Holy. Change spec and the row swaps on its own, with its own colours, icon and lettering.
- **Armor row.** Shows your Armor as a whole number, so you can see armor buffs and debuffs come and go.
- **New slash commands:**
  - `/ss nova`: fake a Haste supernova to see the effect
  - `/ss nova 55`: choose the % where supernova starts (default 60)
  - `/ss nova off` / `/ss nova on`: turn the supernova effect off or on

### Changed
- **Parry removed.** The Armor row takes its place.
- **Brighter highlights.** Numbers now glow in a coloured halo and hop when a stat jumps. Faded "ghost" arrows keep rising off the ▲ arrow while a stat stays up.
- **Cleaner rows.** The stat name sits in the middle and slides up to make room for the `+6.00%` / `-1,240` line. A stat back at its normal value just shows the stat, with no extra "normal" label.
- **Star bursts fly over the panel** now, instead of getting hidden behind the rows.
- **Crit for your role** is now picked from your spec (spell crit for Holy, melee crit for Protection and Retribution) instead of guessed from your gear.

### Fixed
- Spec and talent swaps are picked up more reliably, so the primary stat row and your normal baseline always update after a change.

---

## 2.7.1

- First release.
- Live Strength, Parry, Critical Strike, Haste, Mastery and Versatility in a neon glitter panel.
- Rows glow green with a ▲ arrow when a stat is above normal, and red with a ▼ arrow when it's below, with the exact change shown.
- Star bursts and a light sweep when a proc, trinket or buff moves a stat.
- Learns your normal stats out of combat, and resets when you change gear, spec or talents.
- Movable and resizable panel, with an optional sparkle sound.
- Slash commands: `/ss test`, `/ss unlock`, `/ss lock`, `/ss scale`, `/ss normal`, `/ss sound`, `/ss reset`.

--[[ =========================================================================
  StatSparkle - your stats, live, cartoon style

  Rows (top to bottom):
      Primary stat  = Strength, Agility or Intellect - whichever your current
                      spec uses. Swaps automatically when you change spec.
      Armor         = silver
      Critical Strike = fiery red   Haste = golden yellow
      Mastery = purple              Versatility = teal

  When a buff / proc moves a stat away from your normal value, the row gets
  a GREEN (up) or RED (down) outer border + glow, a bobbing arrow, the
  difference, a glowing number that hops, and a burst of cartoon stars.
  Back to normal -> the extra effects fade away again.

  While a stat is up, tiny cartoon stars pour out to the left and right of
  the number. The stars stay inside the card and never cover the number.

  JACKPOT MODE: a % stat at 50% or more (10% below the supernova point) turns
  gold so it stands apart from plain green "up" rows (and never red, which
  means a stat is DOWN): a purple aura and a gold ring, lightning crackling
  across the card (from Juggernaut Mode), a number and arrow that shift
  between gold and orange, and stars in every colour.

  SUPERNOVA: when a % stat climbs really high (60%+ by default) the number
  turns white-hot and the row goes off like an exploding star - shockwave
  rings, spinning light rays, a flash, sparks and a little screen shake.
  It keeps getting wilder all the way up to 90%.

  "Normal" = your stats out of combat once nothing has changed for a while.
  It is never updated during combat, so long buffs (e.g. Avenging Wrath)
  can't be mistaken for your normal and cause a false "down" afterwards.

  IN COMBAT (Midnight): the game hides your stats from addons - they come in
  as "secret" values that can be shown but not compared. StatSparkle still
  lights rows up by letting the game do the comparison: every in-combat
  effect is a status bar whose fill IS the effect, with the bar's range set
  around your normal value, so it is empty at normal and full once the stat
  is up (or down). See "In-combat effects" below.

  /ss            - help
  /ss test       - fake a proc up + a proc down
  /ss nova       - fake a Haste supernova
  /ss nova 55    - supernova starts at 55% (default 60)
  /ss nova off   - turn the supernova effect off (/ss nova on)
  /ss combat     - preview the in-combat effects out of combat
  /ss sound      - turn the 50%+ shimmer sound off / on
  /ss unlock     - drag it,  /ss lock to finish
  /ss scale 1.2  - resize
  /ss normal     - "my stats right now are normal" (reset the baseline)
  /ss reset
========================================================================= ]]

local ADDON = ...
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

local SETTLE_FIRST = 8        -- first normal: out of combat & unchanged this long
local SETTLE = 30             -- later updates: out of combat & unchanged this long
local THRESHOLD = 0.05        -- % change that counts as "moved"
local NOVA_AT = 60            -- % where a stat goes supernova (warms up 20% before)
local NOVA_RANGE = 30         -- ...and is at full power this far above it

-- the only sound: a shimmer when a % stat climbs to 50%+ (highSound, /ss sound)
local defaults = { point = "CENTER", relPoint = "CENTER", x = 360, y = -40, scale = 1,
                   nova = true, novaAt = NOVA_AT, highSound = true }
local db

local function Print(m) print("|cffffd200Stat|r|cffffffffSparkle|r: " .. tostring(m)) end

local function Readable(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Call(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
end

local function Clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function Lerp(a, b, k) return a + (b - a) * k end

-- ---------------------------------------------------------------------------
-- Primary stat follows your spec: Strength, Agility or Intellect
-- ---------------------------------------------------------------------------
local PRIMARY = {
    str = { label = "Strength", icon = "ico_str", rowArt = "row_str", labelArt = "label_str", stat = 1,
            art = { 186, 61, 256, 64 }, theme = { 0.96, 0.62, 0.24 }, text = { 1.00, 0.82, 0.55 } },
    agi = { label = "Agility", icon = "ico_agi", rowArt = "row_agi", labelArt = "label_agi", stat = 2,
            art = { 148, 61, 256, 64 }, theme = { 1.00, 0.40, 0.70 }, text = { 1.00, 0.74, 0.88 } },
    int = { label = "Intellect", icon = "ico_int", rowArt = "row_int", labelArt = "label_int", stat = 4,
            art = { 177, 53, 256, 64 }, theme = { 0.36, 0.60, 1.00 }, text = { 0.72, 0.84, 1.00 } },
}
local primaryKey = "str"

-- the spec's primary stat (LE_UNIT_STAT_*) -> row
local STAT_KEY = { [1] = "str", [2] = "agi", [4] = "int" }

-- backup if the game won't say which primary stat a spec uses: every Strength and
-- Agility spec by ID. Any other spec (casters, healers, Devourer) is Intellect.
local SPEC_KEY = {
    [71] = "str", [72] = "str", [73] = "str",                 -- Warrior
    [66] = "str", [70] = "str",                               -- Protection / Retribution Paladin
    [250] = "str", [251] = "str", [252] = "str",              -- Death Knight
    [253] = "agi", [254] = "agi", [255] = "agi",              -- Hunter
    [259] = "agi", [260] = "agi", [261] = "agi",              -- Rogue
    [268] = "agi", [269] = "agi",                             -- Brewmaster / Windwalker Monk
    [103] = "agi", [104] = "agi",                             -- Feral / Guardian Druid
    [263] = "agi",                                            -- Enhancement Shaman
    [577] = "agi", [581] = "agi",                             -- Havoc / Vengeance Demon Hunter
}

local function SpecPrimary()
    local CS = C_SpecializationInfo
    local getSpec = (CS and CS.GetSpecialization) or GetSpecialization
    local getInfo = (CS and CS.GetSpecializationInfo) or GetSpecializationInfo
    local idx = Readable(Call(getSpec))
    if idx and getInfo then
        local ok, specID, _, _, _, _, stat = pcall(getInfo, idx)
        if ok then
            stat, specID = Readable(stat), Readable(specID)
            if STAT_KEY[stat] then return STAT_KEY[stat] end
            if specID and specID > 0 then return SPEC_KEY[specID] or "int" end
        end
    end
    -- no spec info yet (loading screen): go by whichever is highest on the gear
    local best, bestV = "str", -1
    for _, key in ipairs({ "str", "agi", "int" }) do
        local v = Readable(Call(UnitStat, "player", PRIMARY[key].stat)) or 0
        if v > bestV then best, bestV = key, v end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Reading the stats (character-sheet %)
-- ---------------------------------------------------------------------------
local CR_VERS = CR_VERSATILITY_DAMAGE_DONE or 29

-- Intellect specs use spell crit, Strength and Agility specs melee/ranged crit;
-- picked by the spec's primary stat so the number never flips between the two
local function IsCaster() return primaryKey == "int" end

-- the highest of several crit readings (melee / ranged, or each spell school).
-- It remembers which one won, so in combat - when the readings are secret and
-- can't be compared - it shows that same one, not a different kind of crit
-- (which would look like a false drop or rise against your normal).
local picked = {}
local function MaxOf(kind, list, n)
    local best, at
    for i = 1, n do
        local v = Readable(list[i])
        if v and (not best or v > best) then best, at = v, i end
    end
    if best then picked[kind] = at return best end
    local p = picked[kind]
    if p and list[p] ~= nil then return list[p] end
    for i = 1, n do if list[i] ~= nil then return list[i] end end
end

local STATS = {
    -- primary stat: a whole number (e.g. 12,345), moves with trinkets / procs / buffs.
    -- label / icon / colours are filled in from PRIMARY by ApplyPrimary()
    { key = "primary", dynamic = true, integer = true, threshold = 1,
      get = function()
          local ok, _, effective = pcall(UnitStat, "player", PRIMARY[primaryKey].stat)   -- base, EFFECTIVE, ...
          if ok then return effective end
      end },
    -- armor: a whole number, moves with armor buffs / debuffs
    { key = "armor", label = "Armor", icon = "ico_armor", integer = true, threshold = 1,
      art = { 144, 52, 256, 64 },
      theme = { 0.80, 0.85, 0.94 }, text = { 0.92, 0.95, 1.00 },
      get = function()
          local ok, _, effective = pcall(UnitArmor, "player")   -- base, EFFECTIVE, armor, bonus
          if ok then return effective end
      end },
    { key = "crit", label = "Critical Strike", icon = "ico_crit", art = { 275, 57, 512, 64 },
      theme = { 1.00, 0.32, 0.12 }, text = { 1.00, 0.72, 0.50 },
      get = function()
          if IsCaster() then
              local t = {}
              for school = 2, 7 do t[school - 1] = Call(GetSpellCritChance, school) end
              return MaxOf("spell", t, 6)
          end
          return MaxOf("melee", { Call(GetCritChance), Call(GetRangedCritChance) }, 2)
      end },
    { key = "haste", label = "Haste", icon = "ico_haste", art = { 131, 54, 256, 64 },
      theme = { 1.00, 0.80, 0.12 }, text = { 1.00, 0.93, 0.55 },
      get = function() return Call(GetHaste) end },
    { key = "mastery", label = "Mastery", icon = "ico_mastery", art = { 176, 60, 256, 64 },
      theme = { 0.66, 0.34, 1.00 }, text = { 0.86, 0.72, 1.00 },
      get = function() return Call(GetMasteryEffect) end },
    { key = "vers", label = "Versatility", icon = "ico_vers", art = { 216, 63, 256, 64 },
      theme = { 0.12, 0.78, 0.85 }, text = { 0.62, 0.96, 1.00 },
      get = function()
          local a, b = Call(GetCombatRatingBonus, CR_VERS), Call(GetVersatilityBonus, CR_VERS)
          if Readable(a) and Readable(b) then return a + b end
          return a
      end },
}
for _, st in ipairs(STATS) do
    st.rowArt = st.rowArt or ("row_" .. st.key)
    st.labelArt = st.labelArt or ("label_" .. st.key)
end
do   -- start the primary row as Strength until the spec is known
    local P, st = PRIMARY.str, STATS[1]
    st.label, st.icon, st.rowArt, st.labelArt, st.art, st.theme, st.text = P.label, P.icon, P.rowArt, P.labelArt, P.art, P.theme, P.text
end

local UP_C, DOWN_C = { 0.30, 1.00, 0.35 }, { 1.00, 0.22, 0.18 }
-- 50%+ jackpot mode: gold and orange (never red - red means a stat is DOWN), purple accents
local JP_PURPLE, JP_GOLD, JP_ORANGE = { 0.62, 0.12, 1.00 }, { 1.00, 0.82, 0.20 }, { 1.00, 0.50, 0.08 }
local HOT_C = { 1.00, 0.97, 0.86 }   -- white-hot colour a supernova number burns towards

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------
local ROW_H, ROW_GAP, PAD, W = 58, 10, 14, 440
local TITLE_H = 48
local ICON_S = 44           -- stat icon size
local NAME_H = 34           -- height of the glitter stat-name lettering
local VALUE_SIZE = 32       -- the big number
local DELTA_SIZE = 15       -- the "+1.23%" under the name while a stat is up/down
local VALUE_X = -58         -- right edge of the number, from the row's right edge
local ARROW_X = -28
local FONT = MEDIA .. "Poppins-Bold.ttf"
local NUMFONT = MEDIA .. "Poppins-Medium.ttf"   -- lighter weight = easier to read numbers
-- pre-rendered neon glitter lettering: { width, height, textureWidth, textureHeight }
local TITLE_ART = { 625, 103, 1024, 128 }
local H = PAD * 2 + TITLE_H + #STATS * ROW_H + (#STATS - 1) * ROW_GAP

local f = CreateFrame("Frame", "StatSparkleFrame", UIParent)
f:SetSize(W, H)
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)
local BASE_LVL = f:GetFrameLevel()

-- black glitter panel with a rainbow neon-tube border (glow baked in, 22px around)
local panel = f:CreateTexture(nil, "BACKGROUND", nil, -6)
panel:SetTexture(MEDIA .. "panel_neon")
panel:SetPoint("TOPLEFT", -22, 22); panel:SetPoint("BOTTOMRIGHT", 22, -22)
-- a second copy that softly pulses, so the neon "breathes"
local panelPulse = f:CreateTexture(nil, "BACKGROUND", nil, -5)
panelPulse:SetTexture(MEDIA .. "panel_neon")
panelPulse:SetAllPoints(panel)
panelPulse:SetBlendMode("ADD")

-- "secondary stats" in rainbow neon glitter letters
local title = f:CreateTexture(nil, "OVERLAY")
title:SetTexture(MEDIA .. "title")
title:SetTexCoord(0, TITLE_ART[1] / TITLE_ART[3], 0, TITLE_ART[2] / TITLE_ART[4])
local titleW = W - 90
title:SetSize(titleW, titleW * TITLE_ART[2] / TITLE_ART[1])
title:SetPoint("TOP", 0, -PAD + 6)

-- twinkling star flares scattered over the space background
local twinkles = {}
for i = 1, 8 do
    local tw = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    tw:SetTexture(MEDIA .. "flare")
    tw:SetBlendMode("ADD")
    tw.size = 14 + math.random() * 18
    tw.speed = 1.2 + math.random() * 2
    tw.phase = math.random() * 6
    tw:SetVertexColor(1, 0.6, 0.2)   -- glowing orange embers
    tw:SetPoint("CENTER", f, "TOPLEFT", 10 + math.random() * (W - 20), -(10 + math.random() * (H - 20)))
    twinkles[i] = tw
end

local dragTex = f:CreateTexture(nil, "OVERLAY")
dragTex:SetAllPoints(); dragTex:SetColorTexture(1, 0.8, 0.2, 0.2); dragTex:Hide()

-- star particles live on their own top layer so bursts fly OVER the cards
local fx = CreateFrame("Frame", nil, f)
fx:SetAllPoints()
fx:SetFrameLevel(BASE_LVL + 10)
local particles, freeP = {}, {}
local MAX_PARTICLES = 260
local function Particle(tex)
    if #particles >= MAX_PARTICLES then return nil end
    local p = table.remove(freeP)
    if not p then
        p = fx:CreateTexture(nil, "OVERLAY", nil, 7)
        p:SetBlendMode("BLEND")
    end
    p:SetTexture(MEDIA .. (tex or "star"))
    p:SetBlendMode(tex == "spark" and "ADD" or "BLEND")
    p:Show()
    p.float, p.drag = nil, nil
    particles[#particles + 1] = p
    return p
end

-- halo copies of the number (in a ring around it) = a coloured outer glow on the text
local HALO = { { 2.5, 0 }, { -2.5, 0 }, { 0, 2.5 }, { 0, -2.5 }, { 1.8, 1.8 }, { -1.8, 1.8 }, { 1.8, -1.8 }, { -1.8, -1.8 },
               { 4.5, 0 }, { -4.5, 0 }, { 0, 4.5 }, { 0, -4.5 }, { 3.2, 3.2 }, { -3.2, 3.2 }, { 3.2, -3.2 }, { -3.2, -3.2 } }

local function ScaleText(fs, s)
    if fs.SetTextScale then pcall(fs.SetTextScale, fs, s) else pcall(fs.SetScale, fs, s) end
end

-- ---------------------------------------------------------------------------
-- In-combat effects
-- ---------------------------------------------------------------------------
-- In combat the game gives StatSparkle secret stat values: they can be shown
-- but not compared with your normal. A StatusBar can still be fed a secret
-- value, and the game itself works out how much of the bar to fill. So each
-- in-combat effect is a status bar whose fill texture IS the effect, with the
-- bar's range set around your normal value: empty at normal, full once the
-- stat is up (or down, or supernova). StatSparkle never learns the answer; it
-- only animates the bars, and only the full ones can be seen.
local function GateBar(list, level, tex, blend, c, a, parent)
    local b = CreateFrame("StatusBar", nil, parent or f)
    b:SetFrameLevel(BASE_LVL + level)
    b:SetStatusBarTexture(tex)
    local fill = b:GetStatusBarTexture()
    if blend then fill:SetBlendMode(blend) end
    if c then b:SetStatusBarColor(c[1], c[2], c[3], a or 1) end
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    b:Hide()
    list[#list + 1] = b
    return b
end

-- paint a row with its stat's art and colours (also used when the primary stat swaps)
local function SkinRow(r)
    local st = r.stat
    r.fill:SetTexture(MEDIA .. st.rowArt)
    r.themeGlow:SetTexture(MEDIA .. st.rowArt)
    r.icon:SetTexture(MEDIA .. st.icon)
    local art = st.art
    r.name:SetTexture(MEDIA .. st.labelArt)
    r.name:SetTexCoord(0, art[1] / art[3], 0, art[2] / art[4])
    r.name:SetSize(NAME_H * art[1] / art[2], NAME_H)
    local tx, th = st.text, st.theme
    r.col = { tx[1], tx[2], tx[3] }
    r.gcol = { th[1], th[2], th[3], 0.18 }
end

local rows = {}
for i, st in ipairs(STATS) do
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(W - PAD * 2, ROW_H)
    r:SetPoint("TOP", f, "TOP", 0, -(PAD + TITLE_H + (i - 1) * (ROW_H + ROW_GAP)))
    r:SetFrameLevel(BASE_LVL + 2)
    r.stat = st
    r.phase = i * 1.3
    -- supernova layer sits above every card, the text layer above that
    r.novaL = CreateFrame("Frame", nil, r); r.novaL:SetAllPoints(); r.novaL:SetFrameLevel(BASE_LVL + 4)
    r.top = CreateFrame("Frame", nil, r);   r.top:SetAllPoints();   r.top:SetFrameLevel(BASE_LVL + 6)

    -- up/down state layers (hidden when normal)
    r.stateGlow = r:CreateTexture(nil, "BACKGROUND", nil, 0)
    r.stateGlow:SetTexture(MEDIA .. "glow_outer")
    r.stateGlow:SetPoint("TOPLEFT", -18, 18); r.stateGlow:SetPoint("BOTTOMRIGHT", 18, -18)
    r.stateGlow:SetBlendMode("ADD"); r.stateGlow:SetAlpha(0)
    r.stateBorder = r:CreateTexture(nil, "BACKGROUND", nil, 2)
    r.stateBorder:SetTexture(MEDIA .. "row_border")
    r.stateBorder:SetPoint("TOPLEFT", -5, 5); r.stateBorder:SetPoint("BOTTOMRIGHT", 5, -5)
    r.stateBorder:SetAlpha(0)

    -- neon card in the stat's colour (dark glitter inside, glowing tube border)
    r.fill = r:CreateTexture(nil, "BORDER", nil, 0)
    r.fill:SetPoint("TOPLEFT", -14, 14); r.fill:SetPoint("BOTTOMRIGHT", 14, -14)
    r.fill:SetAlpha(1)   -- the card art itself is see-through smoky glass
    r.themeGlow = r:CreateTexture(nil, "BORDER", nil, 1)   -- gentle breathing copy
    r.themeGlow:SetAllPoints(r.fill)
    r.themeGlow:SetBlendMode("ADD")

    r.icon = r:CreateTexture(nil, "ARTWORK", nil, 2)
    r.icon:SetSize(ICON_S, ICON_S)
    r.icon:SetPoint("LEFT", 6, 0)

    -- stat name in neon glitter lettering: centred, slides up when the +/- line shows
    r.name = r:CreateTexture(nil, "OVERLAY", nil, 2)
    r.nameY = 0
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 2, 0)

    -- light sweep that runs across the card when a stat goes up
    r.sweep = r:CreateTexture(nil, "OVERLAY", nil, 1)
    r.sweep:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.sweep:SetSize(60, ROW_H - 8)
    r.sweep:SetBlendMode("ADD")
    r.sweep:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 0.8, 0.55))
    r.sweep:Hide()

    -- soft blob behind the number
    r.valueGlow = r:CreateTexture(nil, "ARTWORK", nil, 1)
    r.valueGlow:SetTexture(MEDIA .. "blob")
    r.valueGlow:SetBlendMode("ADD")

    -- ---- supernova pieces (all hidden until a stat gets very high) ----
    local function NovaTex(tex, sub, blend)
        local x = r.novaL:CreateTexture(nil, "ARTWORK", nil, sub)
        x:SetTexture(MEDIA .. tex); x:SetBlendMode(blend or "ADD"); x:SetAlpha(0); x:Hide()
        return x
    end
    r.novaGlow = NovaTex("glow_outer", 0)
    r.novaGlow:SetPoint("TOPLEFT", r, "TOPLEFT", -22, 22); r.novaGlow:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 22, -22)
    r.novaBorder = NovaTex("row_border", 1)
    r.novaBorder:SetPoint("TOPLEFT", r, "TOPLEFT", -5, 5); r.novaBorder:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 5, -5)
    r.novaRays1 = NovaTex("fx_rays", 2)
    r.novaRays2 = NovaTex("fx_rays", 3)
    r.novaCore = NovaTex("blob", 4)
    r.novaFlare = NovaTex("flare", 5)
    r.novaFlash = NovaTex("blob", 6)
    r.rings = {}
    for k = 1, 5 do r.rings[k] = NovaTex("fx_ring", 3) end

    -- ---- text layer ----
    r.arrowGlow = r.top:CreateTexture(nil, "ARTWORK", nil, 3)
    r.arrowGlow:SetTexture(MEDIA .. "blob")
    r.arrowGlow:SetSize(76, 76)
    r.arrowGlow:SetPoint("CENTER", r, "RIGHT", ARROW_X, 0)
    r.arrowGlow:SetBlendMode("ADD"); r.arrowGlow:SetAlpha(0)
    r.arrow = r.top:CreateTexture(nil, "OVERLAY", nil, 5)
    r.arrow:SetSize(38, 38)
    r.arrow:SetPoint("CENTER", r, "RIGHT", ARROW_X, 0)
    r.arrow:Hide()
    -- faded copies of the up-arrow that keep rising off it
    r.ghosts = {}
    for k = 1, 2 do
        local g = r.top:CreateTexture(nil, "OVERLAY", nil, 4)
        g:SetTexture(MEDIA .. "arrow_up"); g:SetBlendMode("ADD"); g:SetAlpha(0)
        g:SetVertexColor(UP_C[1], UP_C[2], UP_C[3])
        g.phase = (k - 1) * 0.5
        r.ghosts[k] = g
    end

    r.delta = r.top:CreateFontString(nil, "OVERLAY")
    r.delta:SetFont(NUMFONT, DELTA_SIZE, "OUTLINE")
    r.delta:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 8, 4)
    r.delta:SetAlpha(0)

    -- the number: rounded font in the stat colour with a black outline
    r.value = r.top:CreateFontString(nil, "OVERLAY", nil, 6)
    r.value:SetFont(NUMFONT, VALUE_SIZE, "OUTLINE")
    r.value:SetShadowColor(0, 0, 0, 0.9)
    r.value:SetShadowOffset(1, -1)
    r.value:SetPoint("RIGHT", r, "RIGHT", VALUE_X, 0)
    -- coloured halo copies behind it (only visible while up/down/glowing hot)
    r.halo = {}
    for k, o in ipairs(HALO) do
        local fs = r.top:CreateFontString(nil, "OVERLAY", nil, k <= 8 and 3 or 2)
        fs:SetFont(NUMFONT, VALUE_SIZE, "")
        fs:SetPoint("CENTER", r.value, "CENTER", o[1], o[2])
        fs:SetAlpha(0)
        fs.inner = k <= 8
        r.halo[k] = fs
    end
    r.valueGlow:SetPoint("TOPLEFT", r.value, "TOPLEFT", -20, 16)
    r.valueGlow:SetPoint("BOTTOMRIGHT", r.value, "BOTTOMRIGHT", 20, -16)

    r.base, r.provisional, r.last, r.lastChange, r.dir, r.pop, r.glowA = nil, true, nil, 0, 0, 0, 0
    r.shake, r.sweepT, r.riseT = 0, nil, 0
    r.heat, r.novaN, r.isNova, r.ringT, r.sparkT, r.flashT = 0, 0, false, 0, 0, nil
    r.jy, r.jv, r.valueW = 0, 0, 90
    SkinRow(r)

    -- ---- effect bars (see GateBar) ----
    --   gUp / gDown / gNova: only in combat, when the stats are secret (out of
    --     combat the normal effects above do this job)
    --   gUpFx / gDownFx / gHigh: always - a soft inner glow, and tiny cartoon
    --     stars pouring out to the left and right of the number for a stat
    --     that is up, or a % stat at 50% or more (10% below the supernova point)
    r.gUp, r.gDown, r.gNova, r.gUpFx, r.gDownFx, r.gHigh = {}, {}, {}, {}, {}, {}
    local function Around(b, m) b:SetPoint("TOPLEFT", r, "TOPLEFT", -m, m); b:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", m, -m) end
    local function Card(g, list, c)
        g.glow2 = GateBar(list, 1, MEDIA .. "glow_outer", "ADD", c, 0.6)   -- wide soft outer glow
        Around(g.glow2, 32)
        g.glow = GateBar(list, 1, MEDIA .. "glow_outer", "ADD", c)         -- tight outer glow
        Around(g.glow, 18)
        g.border = GateBar(list, 1, MEDIA .. "row_border", nil, c)
        Around(g.border, 5)
        g.shine = GateBar(list, 8, MEDIA .. "blob", "ADD", c)              -- faint halo round the number
        g.arrowGlow = GateBar(list, 8, MEDIA .. "blob", "ADD", c)
    end
    -- the stars live in a frame cut to the card, so they never reach the rows
    -- above or below, and sit under the number so they never cover it
    local clip = CreateFrame("Frame", nil, f)
    clip:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -4); clip:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -6, 4)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(BASE_LVL + 4)
    -- a soft inner glow + tiny cartoon stars pouring out either side of the number
    local function Shimmer(g, list, c, stars)
        g.inner = GateBar(list, 3, MEDIA .. "glow_pill", "ADD", c)
        Around(g.inner, -5)
        if not stars then return end
        g.stars = {}
        for k = 1, #stars * 2 do
            local s = GateBar(list, 5, MEDIA .. "star5", nil, stars[(k - 1) % #stars + 1], 1, clip)
            s.phase, s.lastQ, s.side = (k - 1) / (#stars * 2), 0, (k % 2 == 0) and 1 or -1
            s.y0, s.dy, s.sz, s.reach = 0, 0, 9, 0.8
            g.stars[k] = s
        end
    end
    local u, d = {}, {}
    Card(u, r.gUp, UP_C)
    u.tint = GateBar(r.gUp, 7, MEDIA .. "tint_up", "MOD")          -- turns the number green
    u.ghosts = {}
    for k = 1, 2 do
        local g = GateBar(r.gUp, 8, MEDIA .. "arrow_up", "ADD", UP_C)
        g.phase = (k - 1) * 0.5
        u.ghosts[k] = g
    end
    u.arrow = GateBar(r.gUp, 9, MEDIA .. "arrow_up", nil, UP_C)
    u.stars = {}
    local starC = { { 0.4, 1, 0.45 }, { 1, 0.9, 0.3 }, { 1, 1, 1 }, { 0.4, 1, 0.45 } }
    for k = 1, 4 do
        local s = GateBar(r.gUp, 9, MEDIA .. "star", nil, starC[k])
        s.phase, s.jx, s.lastQ = (k - 1) / 4, (math.random() - 0.5) * 30, 0
        u.stars[k] = s
    end
    Card(d, r.gDown, DOWN_C)
    d.tint = GateBar(r.gDown, 7, MEDIA .. "tint_down", "MOD")      -- turns the number red
    d.arrow = GateBar(r.gDown, 9, MEDIA .. "arrow_down", nil, DOWN_C)
    r.gu, r.gd = u, d
    r.fu, r.fd = {}, {}
    local GREEN, GOLD, WHITE = { 0.45, 1, 0.5 }, { 1, 0.85, 0.3 }, { 1, 1, 1 }
    Shimmer(r.fu, r.gUpFx, UP_C, { GREEN, GOLD, { 0.7, 1, 0.6 }, WHITE, GREEN })   -- up: green + gold stars
    Shimmer(r.fd, r.gDownFx, DOWN_C)                                                -- down: no stars
    if not st.integer then
        -- % stats from 50%: JACKPOT MODE - gold and orange with purple accents, so
        -- it stands apart from the plain green of a stat that is only up
        local hi = {}
        hi.aura = GateBar(r.gHigh, 1, MEDIA .. "glow_outer", "ADD", JP_PURPLE)     -- deep purple aura
        Around(hi.aura, 30)
        hi.aura2 = GateBar(r.gHigh, 1, MEDIA .. "glow_outer", "ADD", JP_GOLD)      -- gold glow, close in
        Around(hi.aura2, 16)
        hi.border = GateBar(r.gHigh, 3, MEDIA .. "row_border")                     -- gold ring over the green one
        Around(hi.border, 5)
        Shimmer(hi, r.gHigh, JP_GOLD,
                { GREEN, { 0.75, 0.45, 1 }, { 1, 0.5, 0.8 }, GOLD, { 0.4, 0.9, 1 } })   -- + rainbow stars
        -- lightning crackling across the card (from Juggernaut Mode), behind the number
        hi.bolts = {}
        for k, c in ipairs({ JP_PURPLE, JP_GOLD }) do
            local slot = { speed = k == 1 and 170 or 230, phase = (k - 1) * 230, next = 0, v = 1, bright = 1 }
            for v = 1, 3 do slot[v] = GateBar(r.gHigh, 5, MEDIA .. "bolt" .. v, "ADD", c, 1, clip) end
            hi.bolts[k] = slot
        end
        -- the number: amber, with an even gold <-> orange glow shifting across all of it
        hi.tint = GateBar(r.gHigh, 7, MEDIA .. "tint_fire", "MOD")
        hi.flame = GateBar(r.gHigh, 8, MEDIA .. "glow_box", "ADD", JP_GOLD)
        -- the arrow: a gold one drawn over the green one, in a shimmering orb with sparks
        hi.orb = GateBar(r.gHigh, 9, MEDIA .. "blob", "ADD", JP_GOLD)
        hi.arrow = GateBar(r.gHigh, 10, MEDIA .. "arrow_up")
        hi.sparks = {}
        for k = 1, 2 do
            local s = GateBar(r.gHigh, 10, MEDIA .. "spark", "ADD", k == 1 and { 1, 0.85, 0.5 } or { 0.85, 0.6, 1 })
            s.phase, s.lastQ, s.x, s.y = (k - 1) / 2, 0, 0, 0
            hi.sparks[k] = s
        end
        r.fh = hi
    end
    if not st.integer then   -- % stats can also go supernova
        local n, th = {}, st.theme
        n.glow = GateBar(r.gNova, 4, MEDIA .. "glow_outer", "ADD", th)
        n.glow:SetPoint("TOPLEFT", r, "TOPLEFT", -22, 22); n.glow:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 22, -22)
        n.border = GateBar(r.gNova, 4, MEDIA .. "row_border", "ADD",
                           { Lerp(th[1], 1, 0.6), Lerp(th[2], 0.95, 0.6), Lerp(th[3], 0.7, 0.6) })
        n.border:SetPoint("TOPLEFT", r, "TOPLEFT", -5, 5); n.border:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 5, -5)
        n.rays1 = GateBar(r.gNova, 4, MEDIA .. "fx_rays", "ADD", th, 0.85)
        n.rays2 = GateBar(r.gNova, 4, MEDIA .. "fx_rays", "ADD", { 1, 0.93, 0.65 }, 0.7)
        n.rings = {}
        for k = 1, 3 do
            local g = GateBar(r.gNova, 5, MEDIA .. "fx_ring", "ADD", k == 2 and { 1, 0.97, 0.85 } or th)
            g.phase = (k - 1) / 3
            n.rings[k] = g
        end
        n.core = GateBar(r.gNova, 5, MEDIA .. "blob", "ADD", { Lerp(th[1], 1, 0.55), Lerp(th[2], 1, 0.55), Lerp(th[3], 1, 0.55) })
        n.flare = GateBar(r.gNova, 5, MEDIA .. "flare", "ADD", { 1, 1, 1 })
        n.hot = GateBar(r.gNova, 8, MEDIA .. "blob", "ADD", HOT_C)  -- the number burns white-hot
        r.gn = n
    end
    rows[i] = r
end

-- ---------------------------------------------------------------------------
-- Effects
-- ---------------------------------------------------------------------------
local frameShake, moving = 0, false

local function Burst(r, up)
    local cx, cy = r:GetCenter()
    local fx_, fy = f:GetCenter()
    if not cx or not fx_ then return end
    local ox, oy = cx - fx_, cy - fy
    local th = r.stat.theme
    for k = 1, 8 do
        local p = Particle()
        if not p then break end
        local ang = (k / 8) * math.pi * 2 + math.random() * 0.5
        local speed = 70 + math.random() * 60
        p.x, p.y = ox + (math.random() - 0.5) * (W - 70), oy
        p.vx, p.vy = math.cos(ang) * speed, math.sin(ang) * speed + 40
        p.life, p.max = 0, 0.8 + math.random() * 0.3
        p.size = 13 + math.random() * 11
        p.spin = (math.random() - 0.5) * 10
        p.rot = math.random() * 6
        local pick = math.random(4)
        local c = up and UP_C or DOWN_C
        if pick == 1 then p.r, p.g, p.b = c[1], c[2], c[3]
        elseif pick == 2 then p.r, p.g, p.b = th[1], th[2], th[3]
        elseif pick == 3 then p.r, p.g, p.b = 1, 0.9, 0.25
        else p.r, p.g, p.b = 1, 1, 1 end
    end
    r.pop = 1
    if up then
        r.shake = 1; r.sweepT = 0
        r.jv = math.max(r.jv, 170)   -- the number hops up
    end
end

-- where the number sits, relative to the middle of the whole frame
local function NovaCenter(r)
    local right = r:GetRight()
    local _, cy = r:GetCenter()
    local fx_, fy = f:GetCenter()
    if not right or not cy or not fx_ then return nil end
    return right + VALUE_X - r.valueW / 2 - fx_, cy - fy
end

local function SpawnRing(r, delay, big)
    for _, ring in ipairs(r.rings) do
        if not ring.life then
            ring.life, ring.big = -(delay or 0), big
            ring.white = math.random() < 0.5
            return
        end
    end
end

local function SprayParticles(r, n, speedMul, big)
    local ox, oy = NovaCenter(r)
    if not ox then return end
    local th = r.stat.theme
    for _ = 1, n do
        local spark = math.random() < 0.6
        local p = Particle(spark and "spark" or "star")
        if not p then return end
        local ang = math.random() * math.pi * 2
        local speed = (60 + math.random() * 110) * speedMul
        p.x, p.y = ox + math.cos(ang) * 8, oy + math.sin(ang) * 8
        p.vx, p.vy = math.cos(ang) * speed, math.sin(ang) * speed
        p.life, p.max = 0, 0.6 + math.random() * 0.5
        p.size = (spark and 12 or 8) + math.random() * (big and 16 or 9)
        p.spin, p.rot = (math.random() - 0.5) * 8, math.random() * 6
        p.float, p.drag = true, 1.6
        local pick = math.random(3)
        if pick == 1 then p.r, p.g, p.b = th[1], th[2], th[3]
        elseif pick == 2 then p.r, p.g, p.b = 1, 0.92, 0.55
        else p.r, p.g, p.b = 1, 1, 1 end
    end
end

-- the moment a stat crosses into supernova territory
local function Detonate(r)
    r.flashT = 0
    SpawnRing(r, 0, true); SpawnRing(r, 0.12, true); SpawnRing(r, 0.26, false)
    SprayParticles(r, 34, 1.8, true)
    r.jv = math.max(r.jv, 260)
    r.pop = 1
    frameShake = 1
end

local function ShowNova(r, show)
    local list = { r.novaGlow, r.novaBorder, r.novaRays1, r.novaRays2, r.novaCore, r.novaFlare }
    for _, x in ipairs(list) do if show then x:Show() else x:Hide() end end
    r.novaShown = show
end

local function PlaceAtValue(tex, r, size, jy)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", r, "RIGHT", VALUE_X - r.valueW / 2, jy or 0)
    tex:SetSize(size, size)
end

-- ---- in-combat effects: keep every bar of a row moving; the game decides which show ----
local function GatePlace(b, r, x, y, w, h)
    b:SetPoint("CENTER", r, "RIGHT", x, y)
    b:SetSize(w, h or w)
end

local function AnimateGates(r, t, pulse)
    local vw = r.valueW
    local vx = VALUE_X - vw / 2                 -- middle of the number
    local flick = 0.85 + 0.15 * math.sin(t * 11 + r.phase)
    for _, dir in ipairs({ 1, -1 }) do
        local g = dir > 0 and r.gu or r.gd
        g.glow:SetAlpha(pulse)
        g.glow2:SetAlpha(0.45 + 0.35 * math.sin(t * 2.6 + r.phase))
        g.border:SetAlpha(0.7 + 0.3 * pulse)
        GatePlace(g.tint, r, vx, 0, vw + 30, 56)
        GatePlace(g.shine, r, vx, 0, vw + 40, 56)              -- only a faint halo: the number stays crisp
        g.shine:SetAlpha(0.22 * flick)
        local bob = math.sin(t * 6) * 4 * dir
        GatePlace(g.arrow, r, ARROW_X, bob, 38 * (1 + 0.12 * math.sin(t * 8)))
        GatePlace(g.arrowGlow, r, ARROW_X, bob, 76)
        g.arrowGlow:SetAlpha(0.5 + 0.5 * pulse)
    end
    local u = r.gu
    -- ghost arrows and little stars keep rising off the up-arrow
    for _, gh in ipairs(u.ghosts) do
        local q = (t * 1.1 + gh.phase) % 1
        GatePlace(gh, r, ARROW_X, 4 + q * 26, 30 * (1 - q * 0.4))
        gh:SetAlpha(0.55 * (1 - q) * math.min(1, q * 5))
    end
    for _, s in ipairs(u.stars) do
        local q = (t * 0.9 + s.phase) % 1
        if q < s.lastQ then s.jx = (math.random() - 0.5) * 30 end
        s.lastQ = q
        GatePlace(s, r, ARROW_X + s.jx, 8 + q * 44, 9 + 5 * (1 - q))
        s:SetAlpha((1 - q * q) * math.min(1, q * 6))
    end
    -- supernova: a % stat at or above the supernova %
    local n = r.gn
    if n then
        local beat = 1 + 0.12 * math.sin(t * 9)
        GatePlace(n.core, r, vx, 0, 220 * beat)
        n.core:SetAlpha(0.4 * (0.75 + 0.25 * math.sin(t * 9)))
        GatePlace(n.rays1, r, vx, 0, 300 * (0.95 + 0.05 * math.sin(t * 3)))
        GatePlace(n.rays2, r, vx, 0, 230 * (0.9 + 0.1 * math.sin(t * 6)))
        GatePlace(n.flare, r, vx, 0, 190 * (0.75 + 0.45 * math.abs(math.sin(t * 4.5))))
        n.flare:SetAlpha(0.45)
        n.glow:SetAlpha(0.75 * (0.7 + 0.3 * math.sin(t * 7)))
        n.border:SetAlpha(0.7 * (0.6 + 0.4 * math.sin(t * 14 + r.phase)))
        for _, ring in ipairs(n.rings) do
            local q = (t * 1.2 + ring.phase) % 1
            GatePlace(ring, r, vx, 0, 24 + 300 * (1 - (1 - q) ^ 3))
            ring:SetAlpha((1 - q) ^ 1.5 * 0.85)
        end
        GatePlace(n.hot, r, vx, 0, vw + 40, 60)
        n.hot:SetAlpha(0.12 + 0.06 * math.sin(t * 17))
    end
end

-- ---- tiny cartoon stars pouring out to the left and right of the number ----
-- They start at the number's edges and drift outwards, never across the digits,
-- and the card-shaped frame they live in keeps them off the other rows.
local function AnimateStars(g, r, t, vw, speed)
    local nameW = NAME_H * r.stat.art[1] / r.stat.art[2]
    local nameRight = -(W - PAD * 2) + 6 + ICON_S + 2 + nameW      -- from the row's right edge
    local leftRoom = math.max(10, (VALUE_X - vw) - nameRight - 6)    -- stop before the stat name
    local rightRoom = -6 - VALUE_X - 6                               -- stop before the card's end
    for _, s in ipairs(g.stars) do
        local q = (t * speed + s.phase) % 1
        if q < s.lastQ then              -- a new star: its own height, drift, size and reach
            s.y0 = (math.random() - 0.5) * 16
            s.dy = (math.random() - 0.5) * 14
            s.sz = 9 + math.random() * 6
            s.reach = 0.55 + math.random() * 0.45
        end
        s.lastQ = q
        local edge = s.side < 0 and (VALUE_X - vw - 2) or (VALUE_X + 2)
        local x = edge + s.side * q * (s.side < 0 and leftRoom or rightRoom) * s.reach
        GatePlace(s, r, x, s.y0 + s.dy * q, s.sz * math.min(1, q * 5) * (1 - 0.45 * q))
        s:SetAlpha((1 - q) ^ 0.6)
    end
end

-- ---- 50%+ jackpot mode: gold / orange, lightning, a golden number and arrow ----
local function Mix(a, b, k) return Lerp(a[1], b[1], k), Lerp(a[2], b[2], k), Lerp(a[3], b[3], k) end

local function AnimateFire(hi, r, t, vw)
    local vx = VALUE_X - vw / 2
    local swing = 0.5 + 0.5 * math.sin(t * 3 + r.phase)          -- gold <-> orange
    local flick = 0.85 + 0.15 * math.sin(t * 13 + r.phase)
    hi.aura:SetAlpha(0.55 + 0.35 * math.sin(t * 2.5 + r.phase))
    hi.aura2:SetAlpha((0.3 + 0.25 * swing) * flick)
    hi.border:SetStatusBarColor(Mix(JP_GOLD, JP_ORANGE, swing))
    hi.border:SetAlpha(0.85 + 0.15 * math.sin(t * 9))             -- buzzing neon ring
    hi.inner:SetStatusBarColor(Mix(JP_ORANGE, JP_GOLD, swing))
    hi.inner:SetAlpha(0.18 + 0.1 * math.sin(t * 4 + r.phase))
    -- lightning: sweeps across the card, re-striking with a new shape every few frames
    local now, rowW = GetTime(), W - PAD * 2
    for _, slot in ipairs(hi.bolts) do
        local x = ((t * slot.speed + slot.phase + r.phase * 60) % (rowW + 60)) - 30 - rowW
        if now >= slot.next then
            slot.next = now + 0.05 + math.random() * 0.09
            slot.v = math.random(1, 3)
            slot.bright = (math.random() < 0.15) and 0.25 or (0.7 + math.random() * 0.3)
        end
        for v = 1, 3 do
            local b = slot[v]
            GatePlace(b, r, x, 0, 18, 66)
            b:SetAlpha(v == slot.v and slot.bright or 0)
        end
    end
    -- the number: amber, lit evenly by a glow that shifts gold <-> orange
    GatePlace(hi.tint, r, vx, 0, vw + 30, 56)
    GatePlace(hi.flame, r, vx, 0, vw + 30, 56)
    hi.flame:SetStatusBarColor(Mix(JP_GOLD, JP_ORANGE, 0.5 + 0.5 * math.sin(t * 2.4 + r.phase)))
    hi.flame:SetAlpha(0.38 + 0.04 * math.sin(t * 17))
    -- the arrow: gold <-> orange, in a shimmering orb, sparks twinkling round it
    local bob = math.sin(t * 6) * 4
    GatePlace(hi.arrow, r, ARROW_X, bob, 38 * (1 + 0.12 * math.sin(t * 8)))
    hi.arrow:SetStatusBarColor(Mix(JP_GOLD, JP_ORANGE, swing))
    GatePlace(hi.orb, r, ARROW_X, bob, 62 + 6 * math.sin(t * 7))
    hi.orb:SetStatusBarColor(Mix(JP_ORANGE, JP_GOLD, swing))
    hi.orb:SetAlpha(0.55 + 0.3 * math.sin(t * 7 + r.phase))
    for _, s in ipairs(hi.sparks) do
        local q = (t * 1.4 + s.phase) % 1
        if q < s.lastQ then s.x, s.y = (math.random() - 0.5) * 34, (math.random() - 0.5) * 34 end
        s.lastQ = q
        local tw = math.sin(q * math.pi)
        GatePlace(s, r, ARROW_X + s.x, bob + s.y, 3 + 15 * tw * tw)
        s:SetAlpha(tw)
    end
    AnimateStars(hi, r, t, vw, 0.7)
end

local function AnimateFx(r, t, pulse)
    local vw = r.valueW
    local secret = r.gated              -- in combat we can't tell which state shows, so run them all
    if secret or r.dir > 0 then
        r.fu.inner:SetAlpha(0.2 + 0.12 * pulse)
        AnimateStars(r.fu, r, t, vw, 0.9)
    end
    if secret or r.dir < 0 then
        r.fd.inner:SetAlpha(0.22 + 0.1 * pulse)
    end
    local hi = r.fh
    if hi and (secret or (r.pct and db and r.pct >= db.novaAt - 10)) then
        AnimateFire(hi, r, t, vw)
    end
end

local t = 0
f:SetScript("OnUpdate", function(self, e)
    t = t + e
    -- particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life + e
        local k = p.life / p.max
        if k >= 1 then
            p:Hide(); table.remove(particles, i); freeP[#freeP + 1] = p
        else
            if not p.float then p.vy = p.vy - 160 * e end
            if p.drag then
                local d = math.max(0, 1 - p.drag * e)
                p.vx, p.vy = p.vx * d, p.vy * d
            end
            p.x, p.y = p.x + p.vx * e, p.y + p.vy * e
            p.rot = p.rot + p.spin * e
            p:ClearAllPoints()
            p:SetPoint("CENTER", fx, "CENTER", p.x, p.y)
            local s = p.size * (1 - k * 0.6)
            p:SetSize(s, s)
            p:SetRotation(p.rot)
            p:SetVertexColor(p.r, p.g, p.b, 1 - k * k)
        end
    end
    panelPulse:SetAlpha(0.04 + 0.04 * math.sin(t * 1.6))
    for _, tw in ipairs(twinkles) do
        local k = math.max(0, math.sin(t * tw.speed + tw.phase))
        tw:SetAlpha(k * 0.7)
        local sz = tw.size * (0.6 + 0.6 * k)
        tw:SetSize(sz, sz)
        tw:SetRotation(t * 0.4 + tw.phase)
    end
    title:SetVertexColor(1, 1, 1, 0.9 + 0.1 * math.sin(t * 3))

    -- little shake of the whole window when something goes supernova
    if db and not moving then
        if frameShake > 0 then
            frameShake = math.max(0, frameShake - e * 2.2)
            local amp = 5 * frameShake
            self:ClearAllPoints()
            self:SetPoint(db.point, UIParent, db.relPoint, db.x + (math.random() - 0.5) * 2 * amp, db.y + (math.random() - 0.5) * 2 * amp)
            self.shaken = true
        elseif self.shaken then
            self.shaken = false
            self:ClearAllPoints(); self:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
        end
    end

    local novaOn = not db or db.nova
    local novaAt = db and db.novaAt or NOVA_AT

    for _, r in ipairs(rows) do
        local target = (r.dir ~= 0) and 1 or 0
        r.glowA = r.glowA + (target - r.glowA) * math.min(1, e * 6)
        local pulse = 0.65 + 0.35 * math.sin(t * 5)
        if r.gated then AnimateGates(r, t, pulse) end
        if r.fxShown then AnimateFx(r, t, pulse) end
        local c = r.dir < 0 and DOWN_C or UP_C
        local th = r.stat.theme
        r.stateGlow:SetVertexColor(c[1], c[2], c[3], 1)
        r.stateGlow:SetAlpha(r.glowA * pulse)
        r.stateBorder:SetVertexColor(c[1], c[2], c[3], 1)
        r.stateBorder:SetAlpha(r.glowA * (0.7 + 0.3 * pulse))
        -- theme glow breathes softly all the time
        r.themeGlow:SetAlpha(0.06 + 0.06 * math.sin(t * 2 + r.phase))

        -- ---- heat: how close a % stat is to supernova ----
        local hT, nT = 0, 0
        if novaOn and r.pct then
            hT = Clamp((r.pct - (novaAt - 20)) / (20 + NOVA_RANGE), 0, 1)
            if r.pct >= novaAt then nT = 0.25 + 0.75 * Clamp((r.pct - novaAt) / NOVA_RANGE, 0, 1) end
        end
        r.heat = r.heat + (hT - r.heat) * math.min(1, e * 3)
        r.novaN = r.novaN + (nT - r.novaN) * math.min(1, e * (nT > r.novaN and 5 or 2))
        local nowNova = nT > 0
        if nowNova and not r.isNova then Detonate(r) end
        r.isNova = nowNova
        local h, n = r.heat, r.novaN

        -- ---- the number: jump, shake, throb ----
        if n > 0.05 and r.jy <= 0 and r.jv <= 0 then
            r.jv = 70 + 140 * n                         -- keeps hopping while it's a supernova
        end
        if r.jy > 0 or r.jv ~= 0 then
            r.jv = r.jv - 1100 * e
            r.jy = r.jy + r.jv * e
            if r.jy <= 0 then
                r.jy = 0
                r.jv = (r.jv < -80) and (-r.jv * 0.35) or 0   -- small bounce on landing
            end
        end
        if r.shake > 0 then r.shake = math.max(0, r.shake - e * 1.4) end
        local amp = 4 * r.shake + 2.4 * n
        local jx, jy = 0, r.jy
        if amp > 0.01 then
            jx = (math.random() - 0.5) * 2 * amp
            jy = jy + (math.random() - 0.5) * 2 * amp
        end
        if jx ~= 0 or jy ~= 0 then
            r.value:ClearAllPoints()
            r.value:SetPoint("RIGHT", r, "RIGHT", VALUE_X + jx, jy)
            r.moved = true
        elseif r.moved then
            r.moved = false
            r.value:ClearAllPoints(); r.value:SetPoint("RIGHT", r, "RIGHT", VALUE_X, 0)
        end
        if r.pop > 0 then r.pop = math.max(0, r.pop - e * 2.5) end
        local s = 1 + r.pop * 0.25 + h * 0.04 * math.sin(t * 7) + n * (0.07 + 0.04 * math.sin(t * 13))
        if math.abs(s - (r.lastScale or 1)) > 0.002 then
            ScaleText(r.value, s)
            for _, o in ipairs(r.halo) do ScaleText(o, s) end
            r.lastScale = s
        end
        local is = ICON_S * (1 + r.pop * 0.35 + (r.dir > 0 and 0.06 * math.sin(t * 6) or 0))
        r.icon:SetSize(is, is)

        -- ---- colour: stat colour -> white-hot as it heats up ----
        local col = r.col
        local hot = n * (0.55 + 0.15 * math.sin(t * 17))
        r.value:SetTextColor(Lerp(col[1], HOT_C[1], hot), Lerp(col[2], HOT_C[2], hot), Lerp(col[3], HOT_C[3], hot))
        local gc = r.gcol
        r.valueGlow:SetVertexColor(gc[1], gc[2], gc[3], Clamp(gc[4] + h * 0.45 + n * 0.3, 0, 1))

        -- ---- text outer glow (halo) ----
        local haloA = math.max(r.glowA * 0.5 * pulse, h * 0.45 + n * 0.35)
        if haloA > 0.01 or r.haloShown then
            local hr, hg, hb
            if n > 0.01 or r.dir == 0 then
                local k = n * 0.6
                hr, hg, hb = Lerp(th[1], 1, k), Lerp(th[2], 0.85, k), Lerp(th[3], 0.4, k)
            else hr, hg, hb = c[1], c[2], c[3] end
            local flick = 0.85 + 0.15 * math.sin(t * 11 + r.phase)
            for _, o in ipairs(r.halo) do
                o:SetTextColor(hr, hg, hb)
                o:SetAlpha(haloA * flick * (o.inner and 0.55 or 0.28))
            end
            r.haloShown = haloA > 0.01
        end

        -- ---- stat name slides up to make room for the +/- line ----
        local nameT = (r.dir ~= 0) and 9 or 0
        if math.abs(r.nameY - nameT) > 0.05 then
            r.nameY = r.nameY + (nameT - r.nameY) * math.min(1, e * 10)
            r.name:ClearAllPoints()
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 2, r.nameY)
        end
        r.delta:SetAlpha(r.glowA)

        -- ---- big bobbing arrow on the right + its glow + rising ghost arrows ----
        if r.dir ~= 0 then
            local bob = math.sin(t * 6) * 4 * r.dir
            local sc = 1 + 0.12 * math.sin(t * 8)
            r.arrow:SetSize(38 * sc, 38 * sc)
            r.arrow:SetPoint("CENTER", r, "RIGHT", ARROW_X, bob)
            r.arrowGlow:SetVertexColor(c[1], c[2], c[3], 1)
            r.arrowGlow:SetAlpha(r.glowA * (0.5 + 0.5 * pulse))
            r.arrowGlow:SetPoint("CENTER", r, "RIGHT", ARROW_X, bob)
        else
            r.arrowGlow:SetAlpha(r.glowA * 0.5)
        end
        for _, g in ipairs(r.ghosts) do
            if r.dir > 0 then
                local k = ((t * 1.1) + g.phase) % 1
                g:ClearAllPoints()
                g:SetPoint("CENTER", r, "RIGHT", ARROW_X, 4 + k * 26)
                local gs = 30 * (1 - k * 0.4)
                g:SetSize(gs, gs)
                g:SetAlpha(r.glowA * 0.55 * (1 - k) * math.min(1, k * 5))
            else
                g:SetAlpha(0)
            end
        end
        -- while a stat is UP: little stars keep floating up from the arrow
        if r.dir > 0 then
            r.riseT = r.riseT - e
            if r.riseT <= 0 then
                r.riseT = 0.16
                local cx, cy = r:GetRight(), select(2, r:GetCenter())
                local fx_, fy = self:GetCenter()
                if cx and cy and fx_ then
                    local p = Particle()
                    if p then
                        p.x, p.y = (cx + ARROW_X) - fx_ + (math.random() - 0.5) * 30, cy - fy + 8
                        p.vx, p.vy = (math.random() - 0.5) * 20, 55 + math.random() * 35
                        p.life, p.max = 0, 0.9
                        p.size = 9 + math.random() * 7
                        p.spin, p.rot = (math.random() - 0.5) * 6, math.random() * 6
                        local pick = math.random(3)
                        if pick == 1 then p.r, p.g, p.b = 0.4, 1, 0.45 elseif pick == 2 then p.r, p.g, p.b = 1, 0.9, 0.3 else p.r, p.g, p.b = 1, 1, 1 end
                        p.float = true
                    end
                end
            end
        end
        -- one-off light sweep across the card
        if r.sweepT then
            r.sweepT = r.sweepT + e
            local k = r.sweepT / 0.5
            if k >= 1 then r.sweep:Hide(); r.sweepT = nil
            else
                r.sweep:Show()
                r.sweep:ClearAllPoints()
                r.sweep:SetPoint("CENTER", r, "LEFT", k * r:GetWidth(), 0)
                r.sweep:SetAlpha(1 - k * 0.6)
            end
        end

        -- ---- SUPERNOVA ----
        local vis = math.max(n, h * 0.35)
        if vis > 0.01 then
            if not r.novaShown then ShowNova(r, true) end
            local hotR, hotG, hotB = Lerp(th[1], 1, 0.55), Lerp(th[2], 1, 0.55), Lerp(th[3], 1, 0.55)
            local beat = 1 + 0.12 * math.sin(t * 9)
            -- core glow (already a soft warm glow while "heating up", before the nova)
            PlaceAtValue(r.novaCore, r, (70 + 60 * h + 130 * n) * beat, r.jy * 0.5)
            r.novaCore:SetVertexColor(hotR, hotG, hotB)
            r.novaCore:SetAlpha(Clamp(h * 0.35 + n * 0.65, 0, 1) * (0.75 + 0.25 * math.sin(t * 9)))
            -- two layers of light rays spinning opposite ways
            PlaceAtValue(r.novaRays1, r, 150 + 210 * n, 0)
            r.novaRays1:SetRotation(t * 0.7)
            r.novaRays1:SetVertexColor(th[1], th[2], th[3])
            r.novaRays1:SetAlpha(n * 0.85)
            PlaceAtValue(r.novaRays2, r, (110 + 170 * n) * (0.9 + 0.1 * math.sin(t * 6)), 0)
            r.novaRays2:SetRotation(-t * 1.1 + 0.4)
            r.novaRays2:SetVertexColor(1, 0.93, 0.65)
            r.novaRays2:SetAlpha(n * 0.7)
            -- four-point flare that twinkles on the number
            PlaceAtValue(r.novaFlare, r, (90 + 140 * n) * (0.75 + 0.45 * math.abs(math.sin(t * 4.5))), r.jy * 0.5)
            r.novaFlare:SetRotation(math.sin(t * 1.3) * 0.3)
            r.novaFlare:SetVertexColor(1, 1, 1)
            r.novaFlare:SetAlpha(n)
            -- card border + outer glow burn white-gold and flicker
            local flick = 0.6 + 0.4 * math.sin(t * 14 + r.phase)
            r.novaBorder:SetVertexColor(Lerp(th[1], 1, 0.6), Lerp(th[2], 0.95, 0.6), Lerp(th[3], 0.7, 0.6))
            r.novaBorder:SetAlpha(n * flick)
            r.novaGlow:SetVertexColor(th[1], th[2], th[3])
            r.novaGlow:SetAlpha(Clamp(h * 0.25 + n * 0.75, 0, 1) * (0.7 + 0.3 * math.sin(t * 7)))
            -- shockwave rings, faster and bigger the higher it goes
            if n > 0.01 then
                r.ringT = r.ringT - e
                if r.ringT <= 0 then
                    r.ringT = 0.85 - 0.5 * n
                    SpawnRing(r, 0, n > 0.6)
                end
                -- a constant spray of sparks
                r.sparkT = r.sparkT + e * (10 + 45 * n)
                if r.sparkT >= 1 then
                    local cnt = math.floor(r.sparkT); r.sparkT = r.sparkT - cnt
                    SprayParticles(r, cnt, 1 + n, n > 0.7)
                end
            end
        elseif r.novaShown then
            ShowNova(r, false)
        end
        for _, ring in ipairs(r.rings) do
            if ring.life then
                ring.life = ring.life + e
                local dur = 0.9
                local k = ring.life / dur
                if k >= 1 then
                    ring.life = nil; ring:Hide()
                elseif k >= 0 then
                    ring:Show()
                    local ease = 1 - (1 - k) ^ 3
                    local maxS = ring.big and (240 + 160 * n) or (170 + 120 * n)
                    PlaceAtValue(ring, r, 24 + maxS * ease, 0)
                    if ring.white then ring:SetVertexColor(1, 0.97, 0.85) else ring:SetVertexColor(th[1], th[2], th[3]) end
                    ring:SetAlpha((1 - k) ^ 1.5 * (ring.big and 1 or 0.7))
                end
            end
        end
        -- the white flash when it first goes off
        if r.flashT then
            r.flashT = r.flashT + e
            local k = r.flashT / 0.7
            if k >= 1 then r.flashT = nil; r.novaFlash:Hide()
            else
                r.novaFlash:Show()
                PlaceAtValue(r.novaFlash, r, 40 + 420 * (1 - (1 - k) ^ 2), 0)
                r.novaFlash:SetVertexColor(1, 0.98, 0.9)
                r.novaFlash:SetAlpha((1 - k) ^ 2)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Update logic
-- ---------------------------------------------------------------------------
-- write the number into the main text and all its halo copies
local function SetValue(r, fmt, v)
    local ok = pcall(r.value.SetFormattedText, r.value, fmt, v)
    if not ok then r.value:SetText("--") end
    for _, o in ipairs(r.halo) do
        if not pcall(o.SetFormattedText, o, fmt, v) then o:SetText("--") end
    end
end

-- Strength / Agility / Intellect / Armor show as 12,345; everything else as 12.34%
local function FormatValue(r, v)
    if r.stat.integer then
        local n = math.floor(v + 0.5)
        return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
    end
    return string.format("%.2f%%", v)
end
local function FormatDelta(r, d)
    if r.stat.integer then
        local n = math.floor(math.abs(d) + 0.5)
        return (d >= 0 and "+" or "-") .. (BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n))
    end
    return string.format(d >= 0 and "+%.2f%%" or "%.2f%%", d)
end
local function SetValueText(r, text)
    r.value:SetText(text)
    for _, o in ipairs(r.halo) do o:SetText(text) end
end

-- a secret number: keep the thousands separators (12,345) if the game allows it
local secretCommas = true   -- false once the game refuses, so it isn't retried all fight
local function SetSecretValue(r, raw)
    if secretCommas and r.stat.integer and BreakUpLargeNumbers then
        local ok, s = pcall(BreakUpLargeNumbers, raw)
        if ok and s then SetValueText(r, s) return end
        secretCommas = false
    end
    SetValue(r, r.stat.integer and "%d" or "%.2f%%", raw)
end

-- ---- effect bars: show them and feed them the value ----
local function ShowBars(sets, on)
    for _, set in ipairs(sets) do
        for _, b in ipairs(set) do b:SetShown(on) end
    end
end
local function SetGated(r, on)     -- the in-combat-only bars
    if r.gated == on then return end
    r.gated = on
    ShowBars({ r.gUp, r.gDown, r.gNova }, on)
end
local function SetFx(r, on)        -- the shimmer bars (in and out of combat)
    if r.fxShown == on then return end
    r.fxShown = on
    ShowBars({ r.gUpFx, r.gDownFx, r.gHigh }, on)
end

-- UP-style bars: empty below lo, full from hi
local function FeedUp(set, lo, hi, raw)
    for _, b in ipairs(set) do b:SetMinMaxValues(lo, hi); b:SetValue(raw) end
end

-- DOWN-style bars (red). A status bar only fills further as its value RISES, so
-- "full when the stat is LOW" needs an upside-down range (min above max), and
-- the game can draw that in different ways. TestDownMode() measures how this
-- game draws it at login and picks a way that works:
--   "inverted"  - upside-down ranges fill backwards: range from normal - half a
--                 step down to normal - one step, value = the stat
--   "minsecret" - upside-down ranges draw empty: min = the stat, max = just
--                 above normal - one step, value = normal - one step
--   "none"      - couldn't tell: no red in combat (but never a false red)
local downMode   -- nil until TestDownMode has finished

local function FeedDown(set, base, thr, raw)
    local c = base - thr
    local readable = Readable(raw)
    for _, b in ipairs(set) do
        if readable then                                    -- out of combat / preview
            b:SetMinMaxValues(0, 1); b:SetValue(readable <= c and 1 or 0)
        elseif downMode == "inverted" and pcall(b.SetMinMaxValues, b, base - thr * 0.5, c) then
            b:SetValue(raw)
        elseif downMode == "minsecret" and pcall(b.SetMinMaxValues, b, raw, c + thr * 0.001) then
            b:SetValue(c)
        else
            b:SetMinMaxValues(0, 1); b:SetValue(0)
        end
    end
end

-- How does this game draw a status bar with an upside-down range? Measured once
-- after login on an invisible bar, with plain numbers (nothing secret).
local function TestDownMode()
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetSize(100, 8)
    bar:SetPoint("CENTER")
    bar:SetAlpha(0)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local fill = bar:GetStatusBarTexture()
    local function Filled()                       -- how much of the bar is filled, 0..1
        local ok, w = pcall(fill.GetWidth, fill)
        if not ok or not Readable(w) or not fill:IsShown() then return 0 end
        return w / 100
    end
    local steps = {                               -- { min, max, value }
        { 0, 1, 0.5 },                            -- 1: normal range, half full
        { 1, 0, 0.25 },                           -- 2: upside-down: 0.75 if it fills backwards
        { 0.75, 0.5, 0.49 },                      -- 3: "minsecret" with the stat NOT down: must be empty
        { 0.3, 0.5, 0.49 },                       -- 4: "minsecret" with the stat down: ~full
    }
    local got, i = {}, 0
    local function Near(v, x) return v ~= nil and math.abs(v - x) < 0.1 end
    local function Step()
        if i > 0 and got[i] == nil then got[i] = Filled() end
        i = i + 1
        local s = steps[i]
        if not s then
            bar:Hide()
            if not Near(got[1], 0.5) then downMode = "none"
            elseif Near(got[2], 0.75) then downMode = "inverted"
            elseif Near(got[3], 0) and Near(got[4], 0.95) then downMode = "minsecret"
            else downMode = "none" end
            return
        end
        if pcall(bar.SetMinMaxValues, bar, s[1], s[2]) then
            bar:SetValue(s[3])
        else
            got[i] = (i == 3) and 0 or -1         -- refusing step 3 = "not down" stays empty too
        end
        C_Timer.After(0.2, Step)
    end
    Step()
end
local downTested = false

local function FeedGates(r, raw)   -- in combat: up, down, supernova
    local thr, base = r.stat.threshold or THRESHOLD, r.base
    FeedUp(r.gUp, base + thr * 0.5, base + thr, raw)  -- full from normal + one step
    FeedDown(r.gDown, base, thr, raw)
    if r.gn then                                       -- full from the supernova % up
        local at = db.novaAt
        if db.nova then FeedUp(r.gNova, at - 0.01, at, raw) else FeedUp(r.gNova, 0, 1, 0) end
    end
end

local function FeedFx(r, raw)      -- in and out of combat: shimmer when up / down / 50%+
    local thr, base = r.stat.threshold or THRESHOLD, r.base
    if base then
        FeedUp(r.gUpFx, base + thr * 0.5, base + thr, raw)
        FeedDown(r.gDownFx, base, thr, raw)
    else
        FeedUp(r.gUpFx, 0, 1, 0); FeedUp(r.gDownFx, 0, 1, 0)
    end
    if r.fh then
        local at = db.novaAt - 10
        FeedUp(r.gHigh, at - 0.01, at, raw)
    end
end

local combatDemo   -- /ss combat: until this time, show the in-combat look with real numbers

-- ---- the 50%+ shimmer sound ----
-- Played when a % stat climbs to 50%+ while the game lets StatSparkle see the
-- number (out of combat). In combat the stats are secret, so a crossing can't be
-- noticed; afterwards it quietly catches up instead of playing late.
local SHIMMER_SOUND = (SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST) or 3175
local lastSound = 0
local function HighSound(r, now)
    if not db.highSound or now - lastSound < 3 or now - (r.soundAt or -1e9) < 15 then return end
    lastSound, r.soundAt = now, now
    pcall(PlaySound, SHIMMER_SOUND, "SFX")
end

-- swap the primary row between Strength, Agility and Intellect (only this row changes)
local function ApplyPrimary(key)
    if not PRIMARY[key] then key = "str" end
    if key == primaryKey and rows[1].skinnedFor == key then return end
    local changed = rows[1].skinnedFor ~= nil
    primaryKey = key
    local P, st = PRIMARY[key], STATS[1]
    st.label, st.icon, st.rowArt, st.labelArt, st.art, st.theme, st.text = P.label, P.icon, P.rowArt, P.labelArt, P.art, P.theme, P.text
    local r = rows[1]
    SkinRow(r)
    r.skinnedFor = key
    r.base, r.provisional, r.last = nil, true, nil
    r.dir = 0
    if changed then   -- little celebration in the new colour
        r.pop, r.sweepT, r.jv = 1, 0, 200
        Burst(r, true)
        r.shake = 0
    end
end

local function Update()
    if not db then return end
    local now = GetTime()
    ApplyPrimary(SpecPrimary())
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    for _, r in ipairs(rows) do
        local raw = r.stat.get()
        if r.fake then   -- /ss nova demo
            if now > r.fake.stop then r.fake = nil
            else
                local k = Clamp((now - r.fake.t0) / 2.5, 0, 1)
                raw = Lerp(r.fake.from, r.fake.peak, k)
            end
        end
        local v = Readable(raw)
        local demo = v ~= nil and combatDemo ~= nil and now < combatDemo
        if v == nil or demo then
            -- secret (in combat) or the /ss combat preview: show the number and let
            -- the in-combat effect bars do the up / down / supernova part
            if demo then SetValueText(r, FormatValue(r, v))
            elseif raw ~= nil then SetSecretValue(r, raw)
            else SetValueText(r, "--") end
            r.delta:SetText(""); r.arrow:Hide(); r.dir = 0; r.pct = nil
            r.wasHigh = nil   -- unknown while secret; catch up quietly afterwards
            local tc, thc = r.stat.text, r.stat.theme   -- no leftover green / red from before
            r.col = { tc[1], tc[2], tc[3] }
            r.gcol = { thc[1], thc[2], thc[3], 0.18 }
            SetGated(r, raw ~= nil and r.base ~= nil and pcall(FeedGates, r, raw))
            SetFx(r, raw ~= nil and pcall(FeedFx, r, raw))
        else
            SetGated(r, false)
            SetValueText(r, FormatValue(r, v))
            r.pct = (not r.stat.integer) and v or nil
            local w = Readable(Call(r.value.GetStringWidth, r.value))
            if w and w > 0 then r.valueW = w / (r.lastScale or 1) end
            local thr = r.stat.threshold or THRESHOLD
            if r.base == nil then r.base, r.provisional = v, true end
            if r.last == nil or math.abs(v - r.last) > 0.005 then
                if r.last ~= nil and math.abs(v - r.last) >= thr then Burst(r, v > r.last) end
                r.last, r.lastChange = v, now
            end
            -- learn "normal" only OUT of combat once the value has sat still
            if not inCombat and not r.fake then
                local need = r.provisional and SETTLE_FIRST or SETTLE
                if now - r.lastChange >= need then r.base, r.provisional = v, false end
            end
            local d = v - r.base
            if d >= thr then
                r.dir = 1
                r.arrow:SetTexture(MEDIA .. "arrow_up"); r.arrow:SetVertexColor(UP_C[1], UP_C[2], UP_C[3]); r.arrow:Show()
                r.delta:SetText(FormatDelta(r, d)); r.delta:SetTextColor(0.55, 1, 0.55)
                r.col = { 0.55, 1, 0.55 }
                r.gcol = { UP_C[1], UP_C[2], UP_C[3], 0.8 }
            elseif d <= -thr then
                r.dir = -1
                r.arrow:SetTexture(MEDIA .. "arrow_down"); r.arrow:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3]); r.arrow:Show()
                r.delta:SetText(FormatDelta(r, d)); r.delta:SetTextColor(1, 0.55, 0.5)
                r.col = { 1, 0.55, 0.5 }
                r.gcol = { DOWN_C[1], DOWN_C[2], DOWN_C[3], 0.8 }
            else
                -- back to normal: no extra line under the name, just the stat
                r.dir = 0
                r.arrow:Hide()
                r.delta:SetText("")
                local tc, thc = r.stat.text, r.stat.theme
                r.col = { tc[1], tc[2], tc[3] }
                r.gcol = { thc[1], thc[2], thc[3], 0.18 }
            end
            SetFx(r, pcall(FeedFx, r, raw))
            if r.fh then   -- shimmer sound when a % stat climbs to 50%+
                local high = v >= db.novaAt - 10
                if high and r.wasHigh == false then HighSound(r, now) end
                r.wasHigh = high
            end
        end
    end
end

local function ResetBaseline()
    for _, r in ipairs(rows) do r.base, r.provisional, r.last = nil, true, nil end
end

local function ApplyPosition()
    f:ClearAllPoints()
    f:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    f:SetScale(db.scale)
end

f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) moving = true; self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    moving = false
    local p, _, rp, x, y = self:GetPoint()
    db.point, db.relPoint, db.x, db.y = p, rp, x, y
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "COMBAT_RATING_UPDATE", "MASTERY_UPDATE",
                     "UNIT_STATS", "PLAYER_EQUIPMENT_CHANGED", "SPELL_POWER_CHANGED", "PLAYER_REGEN_ENABLED",
                     "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
                     "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "UNIT_RESISTANCES" }) do
    pcall(ev.RegisterEvent, ev, e)
end
pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        StatSparkleDB = StatSparkleDB or {}
        db = StatSparkleDB
        for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end
        db.sound = nil   -- the old "sound on every change" setting (removed in 2.10.0)
        ApplyPosition()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        C_Timer.After(0.5, function() ResetBaseline(); pcall(Update) end)
    else
        if event == "PLAYER_ENTERING_WORLD" and not downTested then
            downTested = true
            pcall(TestDownMode)
        end
        pcall(Update)
    end
end)
C_Timer.NewTicker(0.25, function() pcall(Update) end)

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
SLASH_STATSPARKLE1 = "/ss"
SLASH_STATSPARKLE2 = "/statsparkle"
SlashCmdList.STATSPARKLE = function(msg)
    local cmd, rest = strsplit(" ", (msg or ""):lower(), 2)
    local byKey = {}
    for _, r in ipairs(rows) do byKey[r.stat.key] = r end
    if cmd == "test" then
        local h, v, sr = byKey.haste, byKey.vers, byKey.primary
        if h.base and v.base then
            local hb, vb = h.base, v.base
            h.base = hb - 4.2; v.base = vb + 1.5
            if sr and sr.base then   -- pretend a primary-stat trinket went off too
                local sb = sr.base; sr.base = sb - 1500; Burst(sr, true)
                C_Timer.After(5, function() sr.base = sb; Update() end)
            end
            Burst(h, true); Burst(v, false); Update()
            C_Timer.After(5, function() h.base, v.base = hb, vb; Update() end)
        end
    elseif cmd == "nova" then
        if rest == "off" then db.nova = false; Print("Supernova effect OFF")
        elseif rest == "on" then db.nova = true; Print("Supernova effect ON (from " .. db.novaAt .. "%)")
        elseif tonumber(rest) then
            local n = tonumber(rest)
            if n >= 10 and n <= 200 then db.novaAt = n; db.nova = true; Print("Supernova now starts at " .. n .. "%")
            else Print("Usage: /ss nova 10-200") end
        else
            -- demo: Haste climbs to ~85% over 2.5s, burns for a few seconds, then settles back
            local h = byKey.haste
            if not db.nova then Print("Supernova is off - /ss nova on") return end
            local from = h.last or 20
            h.fake = { from = from, peak = math.max(from, db.novaAt) + 25, t0 = GetTime(), stop = GetTime() + 9 }
            Update()
        end
    elseif cmd == "combat" then
        -- preview the in-combat look out of combat: Haste up, Versatility down,
        -- Critical Strike climbing into supernova
        local h, v, c = byKey.haste, byKey.vers, byKey.crit
        if not (h.base and v.base and c.base) then Print("Give it a few seconds out of combat first.") return end
        local now = GetTime()
        local function Fake(r, by, floor)   -- a made-up reading; your normal stays untouched
            local from = r.base
            r.fake = { from = from, peak = math.max(from + by, floor or -1e9), t0 = now, stop = now + 8 }
        end
        Fake(h, 4.2)
        Fake(v, -1.5)
        Fake(c, 12, db.novaAt + 12)
        combatDemo = now + 8
        Update()
        Print("Showing the in-combat look for 8 seconds.")
        if downMode == "none" then
            Print("Red for stats below normal isn't available in combat in this version of the game.")
        elseif downMode then
            Print("Red for stats below normal: works in combat too.")
        end
    elseif cmd == "sound" then
        db.highSound = not db.highSound
        Print("50%+ shimmer sound " .. (db.highSound and "ON" or "OFF"))
        if db.highSound then pcall(PlaySound, SHIMMER_SOUND, "SFX") end
    elseif cmd == "unlock" then
        f:EnableMouse(true); dragTex:Show(); Print("Drag it, then /ss lock")
    elseif cmd == "lock" then
        f:EnableMouse(false); dragTex:Hide(); Print("Locked.")
    elseif cmd == "scale" then
        local s = tonumber(rest)
        if s and s >= 0.3 and s <= 3 then db.scale = s; ApplyPosition(); Print("Scale " .. s)
        else Print("Usage: /ss scale 0.3-3") end
    elseif cmd == "normal" then
        for _, r in ipairs(rows) do r.base = r.last; r.provisional = false end
        Update(); Print("Current stats saved as your normal.")
    elseif cmd == "reset" then
        for k, v in pairs(defaults) do db[k] = v end
        ApplyPosition(); Print("Reset.")
    else
        Print("/ss test | combat | nova [on|off|<n>] | sound | unlock | lock | scale <n> | normal | reset")
    end
end

--[[ =========================================================================
  StatSparkle - your secondary stats, live, cartoon style

  Each stat has its own colour theme:
      Critical Strike = fiery red   Haste = golden yellow
      Mastery = purple              Versatility = teal
  When a buff / proc moves a stat away from your normal value, the row gets
  a GREEN (up) or RED (down) outer border + glow, an arrow, the difference,
  and a burst of cartoon stars. Back to normal -> the extra border fades.

  "Normal" = your stats out of combat once nothing has changed for a while.
  It is never updated during combat, so long buffs (e.g. Avenging Wrath)
  can't be mistaken for your normal and cause a false "down" afterwards.

  /ss            - help
  /ss test       - fake a proc up + a proc down
  /ss unlock     - drag it,  /ss lock to finish
  /ss scale 1.2  - resize
  /ss normal     - "my stats right now are normal" (reset the baseline)
  /ss sound      - little sparkle sound on changes (off by default)
  /ss reset
========================================================================= ]]

local ADDON = ...
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

local SETTLE_FIRST = 8        -- first normal: out of combat & unchanged this long
local SETTLE = 30             -- later updates: out of combat & unchanged this long
local THRESHOLD = 0.05        -- % change that counts as "moved"

local defaults = { point = "CENTER", relPoint = "CENTER", x = 360, y = -40, scale = 1, sound = false }
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

-- ---------------------------------------------------------------------------
-- Reading the stats (character-sheet %)
-- ---------------------------------------------------------------------------
local CR_VERS = CR_VERSATILITY_DAMAGE_DONE or 29

-- casters/healers use spell crit, everyone else melee/ranged crit; picked by
-- primary stat so the number never flips between the two
local function IsCaster()
    local int = Readable(Call(UnitStat, "player", 4)) or 0
    local str = Readable(Call(UnitStat, "player", 1)) or 0
    local agi = Readable(Call(UnitStat, "player", 2)) or 0
    return int > math.max(str, agi)
end

local function MaxOf(list)
    local best, secret
    for _, v in ipairs(list) do
        if Readable(v) then
            if not best or v > best then best = v end
        elseif v ~= nil then secret = v end
    end
    return best or secret
end

local STATS = {
    -- primary stat: a whole number (e.g. 12,345), moves with trinkets / procs / buffs
    { key = "str", label = "Strength", icon = "ico_str", integer = true, threshold = 1,
      theme = { 0.96, 0.62, 0.24 }, text = { 1.00, 0.82, 0.55 },
      get = function()
          local ok, _, effective = pcall(UnitStat, "player", 1)   -- base, EFFECTIVE, +buffs, -debuffs
          if ok then return effective end
      end },
    { key = "parry", label = "Parry", icon = "ico_parry",
      theme = { 0.58, 0.72, 1.00 }, text = { 0.80, 0.88, 1.00 },
      get = function() return Call(GetParryChance) end },
    { key = "crit", label = "Critical Strike", icon = "ico_crit",
      theme = { 1.00, 0.32, 0.12 }, text = { 1.00, 0.72, 0.50 },
      get = function()
          if IsCaster() then
              local t = {}
              for school = 2, 7 do t[#t + 1] = Call(GetSpellCritChance, school) end
              return MaxOf(t)
          end
          return MaxOf({ Call(GetCritChance), Call(GetRangedCritChance) })
      end },
    { key = "haste", label = "Haste", icon = "ico_haste",
      theme = { 1.00, 0.80, 0.12 }, text = { 1.00, 0.93, 0.55 },
      get = function() return Call(GetHaste) end },
    { key = "mastery", label = "Mastery", icon = "ico_mastery",
      theme = { 0.66, 0.34, 1.00 }, text = { 0.86, 0.72, 1.00 },
      get = function() return Call(GetMasteryEffect) end },
    { key = "vers", label = "Versatility", icon = "ico_vers",
      theme = { 0.12, 0.78, 0.85 }, text = { 0.62, 0.96, 1.00 },
      get = function()
          local a, b = Call(GetCombatRatingBonus, CR_VERS), Call(GetVersatilityBonus, CR_VERS)
          if Readable(a) and Readable(b) then return a + b end
          return a
      end },
}

local UP_C, DOWN_C = { 0.30, 1.00, 0.35 }, { 1.00, 0.22, 0.18 }

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------
local ROW_H, ROW_GAP, PAD, W = 50, 10, 14, 400
local TITLE_H = 48
local FONT = MEDIA .. "Poppins-Bold.ttf"
local NUMFONT = MEDIA .. "Poppins-Medium.ttf"   -- lighter weight = easier to read numbers
-- pre-rendered neon glitter lettering: { width, height, textureWidth, textureHeight }
local TITLE_ART = { 625, 103, 1024, 128 }
local LABEL_ART = { crit = { 275, 57, 512, 64 }, haste = { 131, 54, 256, 64 }, mastery = { 176, 60, 256, 64 }, vers = { 216, 63, 256, 64 }, str = { 186, 61, 256, 64 }, parry = { 124, 60, 128, 64 } }
local H = PAD * 2 + TITLE_H + #STATS * ROW_H + (#STATS - 1) * ROW_GAP

local f = CreateFrame("Frame", "StatSparkleFrame", UIParent)
f:SetSize(W, H)
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)

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
local titleW = W - 70
title:SetSize(titleW, titleW * TITLE_ART[2] / TITLE_ART[1])
title:SetPoint("TOP", 0, -PAD + 6)

-- twinkling star flares scattered over the space background
local twinkles = {}
for i = 1, 7 do
    local tw = f:CreateTexture(nil, "BACKGROUND", nil, -4)
    tw:SetTexture(MEDIA .. "flare")
    tw:SetBlendMode("ADD")
    tw.size = 14 + math.random() * 18
    tw.speed = 1.2 + math.random() * 2
    tw.phase = math.random() * 6
    local hue = math.random()
    tw:SetVertexColor(1, 0.6, 0.2)   -- glowing orange embers
    tw:SetPoint("CENTER", f, "TOPLEFT", 10 + math.random() * (W - 20), -(10 + math.random() * (H - 20)))
    twinkles[i] = tw
end

local dragTex = f:CreateTexture(nil, "OVERLAY")
dragTex:SetAllPoints(); dragTex:SetColorTexture(1, 0.8, 0.2, 0.2); dragTex:Hide()

-- star particles
local particles, freeP = {}, {}
local function Particle()
    local p = table.remove(freeP)
    if not p then
        p = f:CreateTexture(nil, "OVERLAY", nil, 7)
        p:SetTexture(MEDIA .. "star")
    end
    p:Show()
    p.float = nil
    particles[#particles + 1] = p
    return p
end

local rows = {}
for i, st in ipairs(STATS) do
    local th, tx = st.theme, st.text
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(W - PAD * 2, ROW_H)
    r:SetPoint("TOP", f, "TOP", 0, -(PAD + TITLE_H + (i - 1) * (ROW_H + ROW_GAP)))
    r.stat = st
    r.phase = i * 1.3

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
    r.fill:SetTexture(MEDIA .. "row_" .. st.key)
    r.fill:SetPoint("TOPLEFT", -14, 14); r.fill:SetPoint("BOTTOMRIGHT", 14, -14)
    r.fill:SetAlpha(1)   -- the card art itself is see-through smoky glass
    r.themeGlow = r:CreateTexture(nil, "BORDER", nil, 1)   -- gentle breathing copy
    r.themeGlow:SetTexture(MEDIA .. "row_" .. st.key)
    r.themeGlow:SetAllPoints(r.fill)
    r.themeGlow:SetBlendMode("ADD")

    r.icon = r:CreateTexture(nil, "ARTWORK", nil, 2)
    r.icon:SetTexture(MEDIA .. st.icon); r.icon:SetSize(40, 40)
    r.icon:SetPoint("LEFT", 8, 0)

    -- stat name in neon glitter lettering
    local art = LABEL_ART[st.key]
    r.name = r:CreateTexture(nil, "OVERLAY", nil, 2)
    r.name:SetTexture(MEDIA .. "label_" .. st.key)
    r.name:SetTexCoord(0, art[1] / art[3], 0, art[2] / art[4])
    local nameH = 27
    r.name:SetSize(nameH * art[1] / art[2], nameH)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 0, 8)

    r.arrowGlow = r:CreateTexture(nil, "ARTWORK", nil, 3)
    r.arrowGlow:SetTexture(MEDIA .. "blob")
    r.arrowGlow:SetSize(70, 70)
    r.arrowGlow:SetPoint("CENTER", r, "RIGHT", -26, 0)
    r.arrowGlow:SetBlendMode("ADD"); r.arrowGlow:SetAlpha(0)
    r.arrow = r:CreateTexture(nil, "OVERLAY", nil, 5)
    r.arrow:SetSize(34, 34)
    r.arrow:SetPoint("CENTER", r, "RIGHT", -26, 0)
    r.arrow:Hide()
    -- light sweep that runs across the card when a stat goes up
    r.sweep = r:CreateTexture(nil, "OVERLAY", nil, 1)
    r.sweep:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.sweep:SetSize(50, ROW_H - 8)
    r.sweep:SetBlendMode("ADD")
    r.sweep:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 0.8, 0.55))
    r.sweep:Hide()
    r.delta = r:CreateFontString(nil, "OVERLAY")
    r.delta:SetFont(NUMFONT, 13, "OUTLINE")
    r.delta:SetPoint("LEFT", r.icon, "RIGHT", 8, -12)

    -- the number: chunky rounded font, stat colour, white outline (8 white copies behind it)
    r.value = r:CreateFontString(nil, "OVERLAY", nil, 6)
    r.value:SetFont(NUMFONT, 25, "OUTLINE")
    r.value:SetShadowColor(0, 0, 0, 0.9)
    r.value:SetShadowOffset(1, -1)
    r.value:SetPoint("RIGHT", -52, 0)
    r.value:SetTextColor(tx[1], tx[2], tx[3])   -- light tint of the stat colour
    r.valueOutline = {}
    for _, o in ipairs({}) do   -- (white outline copies removed: they made the numbers hard to read)
        local fs = r:CreateFontString(nil, "OVERLAY", nil, 5)
        fs:SetFont(FONT, 26, "")
        fs:SetTextColor(1, 1, 1)
        fs:SetPoint("CENTER", r.value, "CENTER", o[1], o[2])
        r.valueOutline[#r.valueOutline + 1] = fs
    end
    r.valueGlow = r:CreateTexture(nil, "ARTWORK", nil, 1)
    r.valueGlow:SetTexture(MEDIA .. "blob")
    r.valueGlow:SetPoint("TOPLEFT", r.value, "TOPLEFT", -18, 14)
    r.valueGlow:SetPoint("BOTTOMRIGHT", r.value, "BOTTOMRIGHT", 18, -14)
    r.valueGlow:SetBlendMode("ADD")
    r.valueGlow:SetVertexColor(th[1], th[2], th[3], 0.18)

    r.base, r.provisional, r.last, r.lastChange, r.dir, r.pop, r.glowA = nil, true, nil, 0, 0, 0, 0
    r.shake, r.sweepT, r.riseT = 0, nil, 0
    rows[i] = r
end

-- ---------------------------------------------------------------------------
-- Effects
-- ---------------------------------------------------------------------------
local function Burst(r, up)
    local cx, cy = r:GetCenter()
    local fx, fy = f:GetCenter()
    if not cx or not fx then return end
    local ox, oy = cx - fx, cy - fy
    local th = r.stat.theme
    for k = 1, 8 do
        local p = Particle()
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
    if up then r.shake = 1; r.sweepT = 0 end
    if db and db.sound then pcall(PlaySound, 3175, "SFX") end
end

local t = 0
f:SetScript("OnUpdate", function(self, e)
    t = t + e
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life + e
        local k = p.life / p.max
        if k >= 1 then
            p:Hide(); table.remove(particles, i); freeP[#freeP + 1] = p
        else
            if not p.float then p.vy = p.vy - 160 * e end
            p.x, p.y = p.x + p.vx * e, p.y + p.vy * e
            p.rot = p.rot + p.spin * e
            p:ClearAllPoints()
            p:SetPoint("CENTER", self, "CENTER", p.x, p.y)
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

    for _, r in ipairs(rows) do
        local target = (r.dir ~= 0) and 1 or 0
        r.glowA = r.glowA + (target - r.glowA) * math.min(1, e * 6)
        local pulse = 0.65 + 0.35 * math.sin(t * 5)
        local c = r.dir < 0 and DOWN_C or UP_C
        r.stateGlow:SetVertexColor(c[1], c[2], c[3], 1)
        r.stateGlow:SetAlpha(r.glowA * pulse)
        r.stateBorder:SetVertexColor(c[1], c[2], c[3], 1)
        r.stateBorder:SetAlpha(r.glowA * (0.7 + 0.3 * pulse))
        -- theme glow breathes softly all the time
        r.themeGlow:SetAlpha(0.06 + 0.06 * math.sin(t * 2 + r.phase))
        if r.pop > 0 then
            r.pop = math.max(0, r.pop - e * 2.5)
            local s = 40 * (1 + r.pop * 0.35)
            r.icon:SetSize(s, s)
            pcall(r.value.SetScale, r.value, 1 + r.pop * 0.25)
            for _, o in ipairs(r.valueOutline) do pcall(o.SetScale, o, 1 + r.pop * 0.25) end
        end
        -- number shake when a stat jumps up
        if r.shake > 0 then
            r.shake = math.max(0, r.shake - e * 1.4)
            local amp = 4 * r.shake
            r.value:ClearAllPoints()
            r.value:SetPoint("RIGHT", r, "RIGHT", -52 + (math.random() - 0.5) * 2 * amp, (math.random() - 0.5) * 2 * amp)
        elseif r.shaken then
            r.value:ClearAllPoints(); r.value:SetPoint("RIGHT", -52, 0)
        end
        r.shaken = r.shake > 0
        -- big bobbing arrow on the right + its glow
        if r.dir ~= 0 then
            local bob = math.sin(t * 6) * 4 * r.dir
            local sc = 1 + 0.12 * math.sin(t * 8)
            r.arrow:SetSize(34 * sc, 34 * sc)
            r.arrow:SetPoint("CENTER", r, "RIGHT", -26, bob)
            r.arrowGlow:SetVertexColor(c[1], c[2], c[3], 1)
            r.arrowGlow:SetAlpha(r.glowA * (0.5 + 0.5 * pulse))
            r.arrowGlow:SetPoint("CENTER", r, "RIGHT", -26, bob)
        else
            r.arrowGlow:SetAlpha(r.glowA * 0.5)
        end
        -- while a stat is UP: little stars keep floating up from the arrow
        if r.dir > 0 then
            r.riseT = r.riseT - e
            if r.riseT <= 0 then
                r.riseT = 0.16
                local cx, cy = r:GetRight(), select(2, r:GetCenter())
                local fx, fy = self:GetCenter()
                if cx and cy and fx then
                    local p = Particle()
                    p.x, p.y = (cx - 26) - fx + (math.random() - 0.5) * 30, cy - fy + 8
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
    end
end)

-- ---------------------------------------------------------------------------
-- Update logic
-- ---------------------------------------------------------------------------
-- write the number into the main text and all its white outline copies
local function SetValue(r, fmt, v)
    local ok = pcall(r.value.SetFormattedText, r.value, fmt, v)
    if not ok then r.value:SetText("--") end
    for _, o in ipairs(r.valueOutline) do
        if not pcall(o.SetFormattedText, o, fmt, v) then o:SetText("--") end
    end
end

-- Strength shows as 12,345; everything else as 12.34%
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
    for _, o in ipairs(r.valueOutline) do o:SetText(text) end
end

local function Update()
    if not db then return end
    local now = GetTime()
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    for _, r in ipairs(rows) do
        local raw = r.stat.get()
        local v = Readable(raw)
        if v == nil then
            if raw ~= nil then SetValue(r, r.stat.integer and "%d" or "%.2f%%", raw) else r.value:SetText("--"); for _, o in ipairs(r.valueOutline) do o:SetText("--") end end
            r.delta:SetText(""); r.arrow:Hide(); r.dir = 0
        else
            SetValueText(r, FormatValue(r, v))
            local thr = r.stat.threshold or THRESHOLD
            if r.base == nil then r.base, r.provisional = v, true end
            if r.last == nil or math.abs(v - r.last) > 0.005 then
                if r.last ~= nil and math.abs(v - r.last) >= thr then Burst(r, v > r.last) end
                r.last, r.lastChange = v, now
            end
            -- learn "normal" only OUT of combat once the value has sat still
            if not inCombat then
                local need = r.provisional and SETTLE_FIRST or SETTLE
                if now - r.lastChange >= need then r.base, r.provisional = v, false end
            end
            local d = v - r.base
            if d >= thr then
                r.dir = 1
                r.arrow:SetTexture(MEDIA .. "arrow_up"); r.arrow:SetVertexColor(UP_C[1], UP_C[2], UP_C[3]); r.arrow:Show()
                r.delta:SetText(FormatDelta(r, d)); r.delta:SetTextColor(0.55, 1, 0.55)
                r.value:SetTextColor(0.55, 1, 0.55)
                r.valueGlow:SetVertexColor(UP_C[1], UP_C[2], UP_C[3], 0.8)
            elseif d <= -thr then
                r.dir = -1
                r.arrow:SetTexture(MEDIA .. "arrow_down"); r.arrow:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3]); r.arrow:Show()
                r.delta:SetText(FormatDelta(r, d)); r.delta:SetTextColor(1, 0.55, 0.5)
                r.value:SetTextColor(1, 0.55, 0.5)
                r.valueGlow:SetVertexColor(DOWN_C[1], DOWN_C[2], DOWN_C[3], 0.8)
            else
                r.dir = 0
                r.arrow:Hide()
                r.delta:SetText("normal"); r.delta:SetTextColor(0.75, 0.75, 0.8)
                local tc, thc = r.stat.text, r.stat.theme
                r.value:SetTextColor(tc[1], tc[2], tc[3])
                r.valueGlow:SetVertexColor(thc[1], thc[2], thc[3], 0.18)
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
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.point, db.relPoint, db.x, db.y = p, rp, x, y
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "COMBAT_RATING_UPDATE", "MASTERY_UPDATE",
                     "UNIT_STATS", "PLAYER_EQUIPMENT_CHANGED", "SPELL_POWER_CHANGED", "PLAYER_REGEN_ENABLED",
                     "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        StatSparkleDB = StatSparkleDB or {}
        db = StatSparkleDB
        for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end
        ApplyPosition()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        C_Timer.After(0.5, function() ResetBaseline(); pcall(Update) end)
    else
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
    if cmd == "test" then
        local byKey = {}
        for _, r in ipairs(rows) do byKey[r.stat.key] = r end
        local h, v, sr = byKey.haste, byKey.vers, byKey.str
        if h.base and v.base then
            local hb, vb = h.base, v.base
            h.base = hb - 4.2; v.base = vb + 1.5
            if sr and sr.base then   -- pretend a Strength trinket went off too
                local sb = sr.base; sr.base = sb - 1500; Burst(sr, true)
                C_Timer.After(5, function() sr.base = sb; Update() end)
            end
            Burst(h, true); Burst(v, false); Update()
            C_Timer.After(5, function() h.base, v.base = hb, vb; Update() end)
        end
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
    elseif cmd == "sound" then
        db.sound = not db.sound; Print("Sparkle sound " .. (db.sound and "ON" or "OFF"))
    elseif cmd == "reset" then
        for k, v in pairs(defaults) do db[k] = v end
        ApplyPosition(); Print("Reset.")
    else
        Print("/ss test | unlock | lock | scale <n> | normal | sound | reset")
    end
end

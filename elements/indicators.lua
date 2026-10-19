local _, EUI = ...

-- Status markers on a party row: rest/combat on the player row, one status icon centred on
-- the class icon (with a hover tooltip for some states), leader crown on its top edge, role and
-- PvP on its left edge, and a raid marker before the name. A style without indicators.pvp builds
-- no PvP badge.

EUI.Indicators = {}
local Indicators = {}
Indicators.__index = Indicators

local Style = EUI.Style

local STATE_ICON = 'Interface\\CharacterFrame\\UI-StateIcon'
local REST_FALLBACK = { path = STATE_ICON, coords = { 0, 0.5, 0, 0.421875 } }
local COMBAT_FALLBACK = { path = STATE_ICON, coords = { 0.5, 1, 0, 0.484375 } }
local RAID_MARKERS = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons'
local LEADER_FALLBACK = { path = 'Interface\\GroupFrame\\UI-Group-LeaderIcon', coords = { 0, 1, 0, 1 } }

-- Keys match GetReadyCheckStatus results plus the other centre states.
local STATUS_ICONS = {
    ready = { path = 'Interface\\RaidFrame\\ReadyCheck-Ready' },
    notready = { path = 'Interface\\RaidFrame\\ReadyCheck-NotReady' },
    waiting = { path = 'Interface\\RaidFrame\\ReadyCheck-Waiting' },
    summonPending = { atlas = 'Raid-Icon-SummonPending', summon = true },
    summonAccepted = { atlas = 'Raid-Icon-SummonAccepted', summon = true },
    summonDeclined = { atlas = 'Raid-Icon-SummonDeclined', summon = true },
    resurrect = { atlas = 'RaidFrame-Icon-Rez' },
    phased = { path = 'Interface\\TargetingFrame\\UI-PhasingIcon', coords = { 0.15625, 0.84375, 0.15625, 0.84375 } },
    -- In a cross-faction or public group (UnitInOtherParty).
    otherGroup = { atlas = 'RaidFrame-Icon-LFR' },
}

-- Fallback coords are the small circles on the LFG role sheet.
local ROLE_SHEET = 'Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES'
local ROLE_ICONS = {
    TANK = { atlas = 'roleicon-tiny-tank', coords = { 0, 19 / 64, 22 / 64, 41 / 64 } },
    HEALER = { atlas = 'roleicon-tiny-healer', coords = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 } },
    DAMAGER = { atlas = 'roleicon-tiny-dps', coords = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } },
    -- Raid roles, which Blizzard's raid frames show in place of the assigned role.
    MAINTANK = { atlas = 'RaidFrame-Icon-MainTank', path = 'Interface\\GroupFrame\\UI-Group-MainTankIcon' },
    MAINASSIST = { atlas = 'RaidFrame-Icon-MainAssist', path = 'Interface\\GroupFrame\\UI-Group-MainAssistIcon' },
}

-- The classic PvP sheets hold the badge in the top-left of a 64x64 texture.
local PVP_SHEET_COORDS = { 0, 0.625, 0, 0.625 }
local PVP_ICONS = {
    FFA = { atlas = 'ui-hud-unitframe-player-pvp-ffaicon', path = 'Interface\\TargetingFrame\\UI-PVP-FFA' },
    Alliance = { atlas = 'ui-hud-unitframe-player-pvp-allianceicon', path = 'Interface\\TargetingFrame\\UI-PVP-Alliance' },
    Horde = { atlas = 'ui-hud-unitframe-player-pvp-hordeicon', path = 'Interface\\TargetingFrame\\UI-PVP-Horde' },
}

local FLAG_ICONS = {
    AFK = Style.AssetPath('flags/afk'),
    DND = Style.AssetPath('flags/dnd'),
}

-- Blizzard's GetThreatStatusColor values for statuses 1-3, used when that function is absent.
local THREAT_COLORS = { { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }

-- r, g, b for a plain threat status 1-3 (higher is clamped to 3).
function EUI.Indicators.ThreatColor(status)
    status = math.min(status, 3)
    if GetThreatStatusColor then
        local ok, r, g, b = pcall(GetThreatStatusColor, status)
        if ok and r then
            return r, g, b
        end
    end
    return unpack(THREAT_COLORS[status])
end

-- guide: the Dungeon Guide icon, which replaces the crown in dungeon finder groups
-- (HasLFGRestrictions), as on Blizzard's party and target frames.
function EUI.Indicators.SetLeaderArt(texture, guide)
    guide = guide == true
    if texture.isGuide == guide then
        return
    end
    texture.isGuide = guide
    local atlas = guide and 'UI-HUD-UnitFrame-Player-Group-GuideIcon' or 'UI-HUD-UnitFrame-Player-Group-LeaderIcon'
    Style.SetAtlas(texture, atlas, LEADER_FALLBACK)
end

-- Whether group leaders show as Dungeon Guides.
function EUI.Indicators.IsGuideGroup()
    return EUI.Read('HasLFGRestrictions', HasLFGRestrictions) == true
end

local function sizedTexture(parent, spec)
    local texture = parent:CreateTexture(nil, 'OVERLAY')
    texture:SetSize(spec.size[1], spec.size[2])
    Style.Place(texture, parent, spec.pos)
    texture:Hide()
    return texture
end

local function useFallback(texture, fallback)
    texture:SetTexture(fallback.path)
    texture:SetTexCoord(unpack(fallback.coords))
end

-- Blizzard's player-frame rest loop: a 7x6 flipbook of 42 frames over 1.5s.
local function createRest(parent, spec)
    local texture = sizedTexture(parent, spec)
    if not Style.SetAtlas(texture, 'UI-HUD-UnitFrame-Player-Rest-Flipbook', REST_FALLBACK) then
        return texture, nil
    end
    local ok, group = pcall(function()
        local group = texture:CreateAnimationGroup()
        group:SetLooping('REPEAT')
        local flip = group:CreateAnimation('FlipBook')
        flip:SetFlipBookRows(7)
        flip:SetFlipBookColumns(6)
        flip:SetFlipBookFrames(42)
        flip:SetFlipBookFrameWidth(0)
        flip:SetFlipBookFrameHeight(0)
        flip:SetDuration(1.5)
        return group
    end)
    if ok and group then
        return texture, group
    end
    -- Unanimated, the flipbook atlas shows the whole 42-frame sheet.
    EUI.LogOnce('rest:flipbook', 'rest flipbook animation failed: %s', tostring(group))
    useFallback(texture, REST_FALLBACK)
    return texture, nil
end

-- parent: frame drawn above the class icon. top: the row's text layer.
-- A hover area over the status icon for its tooltip. It takes mouse motion only: clicks fall
-- through to the secure unit button under it, so click-targeting and click-casting keep working
-- there. Without SetMouseClickEnabled there is no hover area.
local function createStatusHover(self, parent)
    local hover = CreateFrame('Frame', nil, parent)
    if not (hover.SetMouseClickEnabled and hover.SetMouseMotionEnabled) then
        EUI.LogOnce('status:hover', 'status tooltips off: SetMouseClickEnabled missing')
        return nil
    end
    hover:SetMouseClickEnabled(false)
    hover:SetMouseMotionEnabled(true)
    hover:SetFrameLevel(parent:GetFrameLevel() + 1)
    hover:SetScript('OnEnter', function()
        if self.statusTooltip then
            GameTooltip:SetOwner(hover, 'ANCHOR_RIGHT')
            GameTooltip:SetText(self.statusTooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)
    hover:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
    hover:Hide()
    return hover
end

function EUI.Indicators.Create(parent, top, style)
    local spec = style.indicators
    local self = setmetatable({ spec = spec, nameSpec = style.txtName, top = top, parent = parent }, Indicators)
    self.leader = sizedTexture(parent, spec.leader)
    EUI.Indicators.SetLeaderArt(self.leader)
    self.assistant = sizedTexture(parent, spec.assistant)
    self.assistant:SetTexture('Interface\\GroupFrame\\UI-Group-AssistantIcon')
    self.masterLooter = sizedTexture(parent, spec.masterLooter)
    self.masterLooter:SetTexture('Interface\\GroupFrame\\UI-Group-MasterLooter')
    self.rest, self.restLoop = createRest(parent, spec.rest)
    self.combat = sizedTexture(parent, spec.combat)
    Style.SetAtlas(self.combat, 'UI-HUD-UnitFrame-Player-CombatIcon', COMBAT_FALLBACK)
    self.status = sizedTexture(parent, spec.status)
    self.statusHover = createStatusHover(self, parent)
    self.raidMarker = sizedTexture(top, spec.raidMarker)
    self.raidMarker:SetTexture(RAID_MARKERS)
    self.flag = sizedTexture(top, spec.flag)
    self.role = sizedTexture(parent, spec.role)
    if spec.pvp then
        self.pvp = sizedTexture(parent, spec.pvp)
    end
    return self
end

-- guide: show the Dungeon Guide icon in place of the crown.
-- A spec entry with hidden set (settings) keeps its indicator hidden.
function Indicators:SetLeader(shown, guide)
    shown = shown and not self.spec.leader.hidden
    if shown then
        EUI.Indicators.SetLeaderArt(self.leader, guide)
    end
    self.leader:SetShown(shown)
end

-- Assistant and master looter stack on the icon's right edge when both show; either one
-- alone sits centred between the two slots. spec.fixedRanks keeps both at their own spots.
local function layoutRightEdge(self)
    if self.spec.fixedRanks then
        return
    end
    local upper, lower = self.spec.assistant.pos, self.spec.masterLooter.pos
    if self.assistant:IsShown() and self.masterLooter:IsShown() then
        Style.Place(self.assistant, self.parent, upper)
        Style.Place(self.masterLooter, self.parent, lower)
    else
        local middle = (upper[2] + lower[2]) / 2
        Style.Place(self.assistant, self.parent, { upper[1], middle })
        Style.Place(self.masterLooter, self.parent, { lower[1], middle })
    end
end

function Indicators:SetAssistant(shown)
    self.assistant:SetShown(shown and not self.spec.assistant.hidden)
    layoutRightEdge(self)
end

function Indicators:SetMasterLooter(shown)
    self.masterLooter:SetShown(shown and not self.spec.masterLooter.hidden)
    layoutRightEdge(self)
end

-- state: 'combat' | 'rest' | nil
function Indicators:SetPlayerState(state)
    if self.spec.rest.hidden then
        state = nil
    end
    self.combat:SetShown(state == 'combat')
    local resting = state == 'rest'
    self.rest:SetShown(resting)
    local loop = self.restLoop
    if loop then
        if resting and not loop:IsPlaying() then
            loop:Play()
        elseif not resting then
            loop:Stop()
        end
    end
end

-- kind: a STATUS_ICONS key, or nil to hide. tooltip: text shown while hovering the icon, or nil.
function Indicators:SetStatus(kind, tooltip)
    if self.spec.status.hidden then
        kind = nil
    end
    self.statusTooltip = tooltip
    if self.statusHover then
        self.statusHover:SetShown(kind ~= nil and tooltip ~= nil)
    end
    if kind == self.statusKind then
        return
    end
    self.statusKind = kind
    local icon = kind and STATUS_ICONS[kind]
    if not icon then
        self.status:Hide()
        return
    end
    local slot = icon.summon and self.spec.summon or self.spec.status
    self.status:SetSize(slot.size[1], slot.size[2])
    Style.Place(self.status, self.parent, slot.pos)
    if self.statusHover then
        self.statusHover:SetSize(slot.size[1], slot.size[2])
        Style.Place(self.statusHover, self.parent, slot.pos)
    end
    if icon.atlas then
        if not Style.SetAtlas(self.status, icon.atlas) then
            self.status:Hide()
            return
        end
    else
        self.status:SetTexture(icon.path)
        self.status:SetTexCoord(unpack(icon.coords or { 0, 1, 0, 1 }))
    end
    self.status:Show()
end

-- index: from EUI.Indicators.ReadRaidMarker (possibly secret), a plain 1-8, or nil.
function Indicators:SetRaidMarker(index)
    if self.spec.raidMarker.hidden then
        self.raidMarker:Hide()
        return
    end
    EUI.Indicators.SetRaidMarkerIcon(self.raidMarker, index)
end

-- GetRaidTargetIndex is secret on Forever, and nil for yourself and friendly NPCs while solo.
-- SetSpriteSheetCell takes the secret index and rejects a missing one, so nothing else touches it.
function EUI.Indicators.ReadRaidMarker(unit)
    local ok, index = pcall(GetRaidTargetIndex, unit)
    if not ok then
        EUI.LogOnce('raidMarker:error', 'GetRaidTargetIndex: %s', tostring(index))
        return nil
    end
    return index
end

-- Shows marker index on texture, or hides it when there is none. Returns whether it shows.
function EUI.Indicators.SetRaidMarkerIcon(texture, index)
    texture:SetTexture(RAID_MARKERS)
    local ok, err = pcall(texture.SetSpriteSheetCell, texture, index, 4, 4)
    if not ok then
        if type(index) ~= 'nil' then
            EUI.LogOnce('raidMarker:cell', 'SetSpriteSheetCell: %s', tostring(err))
        end
        texture:Hide()
        return false
    end
    texture:Show()
    return true
end

-- role: a ROLE_ICONS key ('MAINTANK', 'MAINASSIST' or a UnitGroupRolesAssigned result). 'NONE'
-- and nil hide the icon.
function Indicators:SetRole(role)
    if self.spec.role.hidden then
        role = nil
    end
    if role == self.roleKind then
        return
    end
    self.roleKind = role
    local icon = role and ROLE_ICONS[role]
    if not icon then
        self.role:Hide()
        return
    end
    Style.SetAtlas(self.role, icon.atlas, { path = icon.path or ROLE_SHEET, coords = icon.coords or { 0, 1, 0, 1 } })
    self.role:Show()
end

-- kind: 'FFA' | 'Alliance' | 'Horde' | nil
function Indicators:SetPvP(kind)
    if self.pvp and self.spec.pvp.hidden then
        kind = nil
    end
    if not self.pvp or kind == self.pvpKind then
        return
    end
    self.pvpKind = kind
    self.pvp:SetShown(kind ~= nil and EUI.Indicators.SetPvPIcon(self.pvp, kind))
end

-- Applies the badge for kind ('FFA' | 'Alliance' | 'Horde') to texture; false for an unknown kind.
function EUI.Indicators.SetPvPIcon(texture, kind)
    local icon = PVP_ICONS[kind]
    if not icon then
        return false
    end
    Style.SetAtlas(texture, icon.atlas, { path = icon.path, coords = PVP_SHEET_COORDS })
    return true
end

-- kind: 'AFK' | 'DND' | nil. Call LayoutNameLine afterwards.
function Indicators:SetFlag(kind)
    EUI.Indicators.SetFlagIcon(self.flag, not self.spec.flag.hidden and kind or nil)
end

-- Shows the badge for kind ('AFK' | 'DND') on texture, or hides it for nil. Returns whether it shows.
function EUI.Indicators.SetFlagIcon(texture, kind)
    local path = kind and FLAG_ICONS[kind]
    if path then
        texture:SetTexture(path)
    end
    texture:SetShown(path ~= nil)
    return path ~= nil
end

-- A raid marker, then an AFK/DND flag, sit where the name starts and push the name right.
function Indicators:LayoutNameLine(nameText)
    local nameSpec = self.nameSpec
    local shift = EUI.UnitVisual.NameLineShift(self.top, self.raidMarker, self.spec.raidMarker, self.flag, self.spec.flag)
    nameText:ClearAllPoints()
    nameText:SetPoint('TOPLEFT', self.top, 'TOPLEFT', nameSpec.pos[1] + shift, -nameSpec.pos[2])
    nameText:SetWidth(nameSpec.width - shift)
end

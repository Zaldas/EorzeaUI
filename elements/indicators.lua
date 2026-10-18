local _, AV = ...

-- Status markers on a party row: rest/combat on the player row, one status icon centred on
-- the class icon, leader crown on its top edge, role and PvP on its left edge, and a raid
-- marker before the name.

AV.Indicators = {}
local Indicators = {}
Indicators.__index = Indicators

local Style = AV.Style

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
}

-- Fallback coords are the small circles on the LFG role sheet.
local ROLE_SHEET = 'Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES'
local ROLE_ICONS = {
    TANK = { atlas = 'roleicon-tiny-tank', coords = { 0, 19 / 64, 22 / 64, 41 / 64 } },
    HEALER = { atlas = 'roleicon-tiny-healer', coords = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 } },
    DAMAGER = { atlas = 'roleicon-tiny-dps', coords = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } },
}

-- The classic PvP sheets hold the badge in the top-left of a 64x64 texture.
local PVP_SHEET_COORDS = { 0, 0.625, 0, 0.625 }
local PVP_ICONS = {
    FFA = { atlas = 'ui-hud-unitframe-player-pvp-ffaicon', path = 'Interface\\TargetingFrame\\UI-PVP-FFA' },
    Alliance = { atlas = 'ui-hud-unitframe-player-pvp-allianceicon', path = 'Interface\\TargetingFrame\\UI-PVP-Alliance' },
    Horde = { atlas = 'ui-hud-unitframe-player-pvp-hordeicon', path = 'Interface\\TargetingFrame\\UI-PVP-Horde' },
}

-- Blizzard's GetThreatStatusColor values for statuses 1-3, used when that function is absent.
local THREAT_COLORS = { { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }

-- r, g, b for a plain threat status 1-3 (higher is clamped to 3).
function AV.Indicators.ThreatColor(status)
    status = math.min(status, 3)
    if GetThreatStatusColor then
        local ok, r, g, b = pcall(GetThreatStatusColor, status)
        if ok and r then
            return r, g, b
        end
    end
    return unpack(THREAT_COLORS[status])
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
    AV.LogOnce('rest:flipbook', 'rest flipbook animation failed: %s', tostring(group))
    useFallback(texture, REST_FALLBACK)
    return texture, nil
end

-- parent: frame drawn above the class icon. top: the row's text layer.
function AV.Indicators.Create(parent, top, style)
    local spec = style.indicators
    local self = setmetatable({ spec = spec, nameSpec = style.txtName, top = top, parent = parent }, Indicators)
    self.leader = sizedTexture(parent, spec.leader)
    Style.SetAtlas(self.leader, 'UI-HUD-UnitFrame-Player-Group-LeaderIcon', LEADER_FALLBACK)
    self.assistant = sizedTexture(parent, spec.assistant)
    self.assistant:SetTexture('Interface\\GroupFrame\\UI-Group-AssistantIcon')
    self.masterLooter = sizedTexture(parent, spec.masterLooter)
    self.masterLooter:SetTexture('Interface\\GroupFrame\\UI-Group-MasterLooter')
    self.rest, self.restLoop = createRest(parent, spec.rest)
    self.combat = sizedTexture(parent, spec.combat)
    Style.SetAtlas(self.combat, 'UI-HUD-UnitFrame-Player-CombatIcon', COMBAT_FALLBACK)
    self.status = sizedTexture(parent, spec.status)
    self.raidMarker = sizedTexture(top, spec.raidMarker)
    self.raidMarker:SetTexture(RAID_MARKERS)
    self.role = sizedTexture(parent, spec.role)
    self.pvp = sizedTexture(parent, spec.pvp)
    return self
end

function Indicators:SetLeader(shown)
    self.leader:SetShown(shown)
end

-- Assistant and master looter stack on the icon's right edge when both show; either one
-- alone sits centred between the two slots.
local function layoutRightEdge(self)
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
    self.assistant:SetShown(shown)
    layoutRightEdge(self)
end

function Indicators:SetMasterLooter(shown)
    self.masterLooter:SetShown(shown)
    layoutRightEdge(self)
end

-- state: 'combat' | 'rest' | nil
function Indicators:SetPlayerState(state)
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

-- kind: a STATUS_ICONS key, or nil to hide.
function Indicators:SetStatus(kind)
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

-- index: 1-8 from GetRaidTargetIndex, or nil.
function Indicators:SetRaidMarker(index)
    AV.Indicators.SetRaidMarkerIcon(self.raidMarker, index)
end

-- Shows marker index (1-8) on texture, or hides it for anything else. Returns whether it shows.
function AV.Indicators.SetRaidMarkerIcon(texture, index)
    if index and index >= 1 and index <= 8 then
        local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
        texture:SetTexture(RAID_MARKERS)
        texture:SetTexCoord(column * 0.25, (column + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
        texture:Show()
        return true
    end
    texture:Hide()
    return false
end

-- role: UnitGroupRolesAssigned result. 'NONE' and nil hide the icon.
function Indicators:SetRole(role)
    if role == self.roleKind then
        return
    end
    self.roleKind = role
    local icon = role and ROLE_ICONS[role]
    if not icon then
        self.role:Hide()
        return
    end
    Style.SetAtlas(self.role, icon.atlas, { path = ROLE_SHEET, coords = icon.coords })
    self.role:Show()
end

-- kind: 'FFA' | 'Alliance' | 'Horde' | nil
function Indicators:SetPvP(kind)
    if kind == self.pvpKind then
        return
    end
    self.pvpKind = kind
    self.pvp:SetShown(kind ~= nil and AV.Indicators.SetPvPIcon(self.pvp, kind))
end

-- Applies the badge for kind ('FFA' | 'Alliance' | 'Horde') to texture; false for an unknown kind.
function AV.Indicators.SetPvPIcon(texture, kind)
    local icon = PVP_ICONS[kind]
    if not icon then
        return false
    end
    Style.SetAtlas(texture, icon.atlas, { path = icon.path, coords = PVP_SHEET_COORDS })
    return true
end

-- A raid marker sits where the name starts and pushes the name right.
function Indicators:LayoutNameLine(nameText)
    local nameSpec = self.nameSpec
    local shift = self.raidMarker:IsShown() and (self.spec.raidMarker.size[1] + 3) or 0
    nameText:ClearAllPoints()
    nameText:SetPoint('TOPLEFT', self.top, 'TOPLEFT', nameSpec.pos[1] + shift, -nameSpec.pos[2])
    nameText:SetWidth(nameSpec.width - shift)
end

local _, EUI = ...

EUI.UnitInfo = {}
local UnitInfo = EUI.UnitInfo

-- Forever player names are two-part: UnitName's second return is the surname, not a realm.

local function surnameSeparator()
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    return consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or ' '
end

-- Unit tooltip on hover, owned by button so GameTooltip's OnUpdate calls UpdateTooltip and the
-- tooltip follows the unit (a Tab-target under the cursor). getUnit returns the current token.
function EUI.AttachUnitTooltip(button, getUnit)
    local function show(self)
        local unit = getUnit()
        if unit and UnitExists(unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        elseif GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end
    button.UpdateTooltip = show
    button:HookScript('OnEnter', show)
    button:HookScript('OnLeave', function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
end

-- Returns "First Surname" when both parts are readable; otherwise the raw first name, which
-- may be secret and must only be passed to SetText.
function EUI.UnitDisplayName(unit)
    local first, surname = UnitName(unit)
    if not EUI.CanAccess(first) or not EUI.CanAccess(surname) then
        return first
    end
    if first and surname and surname ~= '' then
        return first .. surnameSeparator() .. surname
    end
    return first
end

local function inGroup(unit)
    return EUI.Read('UnitInParty', UnitInParty, unit) == true or EUI.Read('UnitInRaid', UnitInRaid, unit) ~= nil
end

-- Returns the spec.reactionColors key for unit, and whether it is a living NPC you cannot
-- attack. Players and their pets follow UnitSelectionColor's player branches: attacks you
-- (hostile, or blue when you cannot attack back), attackable (neutral), PvP-flagged (friendly),
-- else blue; your own and group members' get 'party' / 'partyPvP' so a palette can set them
-- apart. NPCs: tap-denied, then UnitReaction.
function UnitInfo.ReactionKey(unit)
    local canAttack = EUI.Read('UnitCanAttack', UnitCanAttack, 'player', unit) == true
    if EUI.Read('UnitPlayerControlled', UnitPlayerControlled, unit) then
        if EUI.Read('UnitCanAttack', UnitCanAttack, unit, 'player') == true then
            return canAttack and 'hostilePlayer' or 'player', false
        elseif canAttack then
            return 'neutral', false
        end
        local flagged = EUI.Read('UnitIsPVP', UnitIsPVP, unit) == true
        local own = EUI.Read('UnitIsUnit', UnitIsUnit, unit, 'player') or EUI.Read('UnitIsUnit', UnitIsUnit, unit, 'pet')
        if own or (EUI.Read('UnitIsPlayer', UnitIsPlayer, unit) and inGroup(unit)) then
            return flagged and 'partyPvP' or 'party', false
        end
        return flagged and 'friendly' or 'player', false
    end
    if EUI.Read('UnitIsTapDenied', UnitIsTapDenied, unit) then
        return 'tapped', false
    end
    local npc = not canAttack and not EUI.Read('UnitIsDead', UnitIsDead, unit)
    local reaction = EUI.Read('UnitReaction', UnitReaction, unit, 'player')
    if type(reaction) ~= 'number' then
        return 'neutral', npc
    elseif reaction <= 2 then
        return 'hostile', npc
    elseif reaction == 3 then
        return 'unfriendly', npc
    elseif reaction == 4 then
        return 'neutral', npc
    end
    return 'friendly', npc
end

-- ReactionKey results for units you can attack; only these get a difficulty-coloured level.
UnitInfo.ATTACKABLE = { hostile = true, unfriendly = true, neutral = true, tapped = true, hostilePlayer = true }

-- 'FFA', the faction of a PvP-flagged unit, or nil.
function UnitInfo.PvPKind(unit)
    if EUI.Read('UnitIsPVPFreeForAll', UnitIsPVPFreeForAll, unit) then
        return 'FFA'
    elseif EUI.Read('UnitIsPVP', UnitIsPVP, unit) then
        return EUI.Read('UnitFactionGroup', UnitFactionGroup, unit)
    end
    return nil
end

-- r, g, b for a level, or nil. unit (optional) uses the client's content difficulty.
function UnitInfo.DifficultyColor(unit, level)
    if level <= 0 then
        local skull = QuestDifficultyColors and QuestDifficultyColors.impossible
        if skull then
            return skull.r, skull.g, skull.b
        end
        return 1, 0.1, 0.1
    end
    local color
    if unit and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer and GetDifficultyColor then
        local difficulty = EUI.Read('GetContentDifficultyCreatureForPlayer', C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)
        color = difficulty and EUI.Read('GetDifficultyColor', GetDifficultyColor, difficulty)
    end
    if not color and GetCreatureDifficultyColor then
        color = EUI.Read('GetCreatureDifficultyColor', GetCreatureDifficultyColor, level)
    end
    if color then
        return color.r, color.g, color.b
    end
    return nil
end

-- Labels that replace a health number.
UnitInfo.STATE_LABELS = {
    dead = DEAD and DEAD:upper() or 'DEAD',
    ghost = GHOST and GHOST:upper() or 'GHOST',
    offline = PLAYER_OFFLINE and PLAYER_OFFLINE:upper() or 'OFFLINE',
    unconscious = UNCONSCIOUS and UNCONSCIOUS:upper() or 'UNCONSCIOUS',
}

-- 'unconscious' or 'dead' for a connected unit at zero health, else nil; Blizzard's target frame
-- (CheckDead) shows the same two.
function UnitInfo.DeadState(unit)
    if EUI.Read('UnitIsConnected', UnitIsConnected, unit) == false then
        return nil
    end
    if EUI.Read('UnitIsUnconscious', UnitIsUnconscious, unit) then
        return 'unconscious'
    end
    if EUI.Read('UnitIsDead', UnitIsDead, unit) then
        return 'dead'
    end
    return nil
end


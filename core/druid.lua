local _, AV = ...

-- Druid bear/cat state, shared by the party row (form power bar) and the party list (the secure
-- driver that grows the player's row). Read from the bonus action bar offset, which Blizzard
-- pages the main bar by: cat 1, prowl 2, bear 3, whichever forms the druid knows. [form:N]
-- cannot be used: form numbers follow the order the forms were learned.

AV.Druid = {}
local Druid = AV.Druid

Druid.CONDITION = '[bonusbar:1/2/3] shifted; caster'
local SHIFTED_BARS = { [1] = true, [2] = true, [3] = true }
local MANA = 0

local getBonusBarOffset = C_ActionBar and C_ActionBar.GetBonusBarOffset or GetBonusBarOffset

function Druid.IsDruid()
    if Druid.isDruid == nil then
        local class = AV.SafeValue(function() return select(2, UnitClass('player')) end)
        if class == nil then
            return false
        end
        Druid.isDruid = class == 'DRUID'
    end
    return Druid.isDruid
end

-- Mirrors CONDITION, so the form bar shows exactly when the driver gives the row its space.
function Druid.IsShifted()
    if not Druid.IsDruid() then
        return false
    end
    local offset = AV.Read('GetBonusBarOffset', getBonusBarOffset)
    local shifted = SHIFTED_BARS[offset] == true
    local powerType = AV.Read('UnitPowerType', UnitPowerType, 'player')
    if powerType ~= nil and shifted == (powerType == MANA) then
        AV.LogOnce('druid:mismatch', 'druid: bonus bar %s with power type %s; [bonusbar:1/2/3] may not mean bear/cat here',
            tostring(offset), tostring(powerType))
    end
    return shifted
end

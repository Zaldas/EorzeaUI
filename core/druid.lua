local _, AV = ...

-- Druid bear/cat state, shared by the party row (form power bar) and the party list (the secure
-- driver that grows the player's row). Form numbers follow the stance bar: with the usual
-- Classic set, bear is 1 and cat is 3; aquatic, travel and moonkin keep mana.

AV.Druid = {}
local Druid = AV.Druid

Druid.CONDITION = '[form:1/3] shifted; caster'
local SHIFTED_FORMS = { [1] = true, [3] = true }
local MANA = 0

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
    local form = AV.Read('GetShapeshiftForm', GetShapeshiftForm)
    local shifted = SHIFTED_FORMS[form] == true
    local powerType = AV.Read('UnitPowerType', UnitPowerType, 'player')
    if powerType ~= nil and shifted == (powerType == MANA) then
        AV.LogOnce('druid:mismatch', 'druid: form %s with power type %s; [form:1/3] may not mean bear/cat here',
            tostring(form), tostring(powerType))
    end
    return shifted
end

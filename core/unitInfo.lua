local _, EUI = ...

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

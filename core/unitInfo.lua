local _, AV = ...

-- Forever player names are two-part: UnitName's second return is the surname, not a realm.

local function surnameSeparator()
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    return consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or ' '
end

-- Returns "First Surname" when both parts are readable; otherwise the raw first name, which
-- may be secret and must only be passed to SetText.
function AV.UnitDisplayName(unit)
    local first, surname = UnitName(unit)
    if not AV.CanAccess(first) or not AV.CanAccess(surname) then
        return first
    end
    if first and surname and surname ~= '' then
        return first .. surnameSeparator() .. surname
    end
    return first
end

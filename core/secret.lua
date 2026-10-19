local _, EUI = ...

-- Forever returns secret values for health, power, cast info and more. Tainted code may pass
-- them to widget sinks (StatusBar:SetValue, FontString:SetText) but errors on compare/arithmetic.

function EUI.CanAccess(value)
    if canaccessvalue then
        local ok, accessible = pcall(canaccessvalue, value)
        if ok then
            return accessible == true
        end
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if ok then
            return secret ~= true
        end
    end
    return true
end

-- Returns the value when it is readable, nil when the call fails or the result is secret.
function EUI.SafeValue(fn, ...)
    if type(fn) ~= 'function' then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        EUI.LogOnce('safe:' .. tostring(value), 'call failed: %s', tostring(value))
        return nil
    end
    if not EUI.CanAccess(value) then
        return nil
    end
    return value
end

function EUI.SafeBool(fn, ...)
    return EUI.SafeValue(fn, ...) == true
end

-- Sends a possibly-secret number to a FontString with thousands separators, after prefix
-- (optional).
function EUI.SetNumberText(fontString, value, prefix)
    if value == nil then
        fontString:SetText('')
        return
    end
    prefix = prefix or ''
    if BreakUpLargeNumbers then
        local ok, text = pcall(BreakUpLargeNumbers, value)
        if ok and pcall(function() fontString:SetText(string.format('%s%s', prefix, text)) end) then
            return
        end
    end
    if not pcall(fontString.SetFormattedText, fontString, prefix .. '%d', value) then
        fontString:SetText('')
    end
end

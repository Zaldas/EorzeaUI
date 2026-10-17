local _, AV = ...

-- Forever returns secret values for health, power, cast info and more. Tainted code may pass
-- them to widget sinks (StatusBar:SetValue, FontString:SetText) but errors on compare/arithmetic.

function AV.CanAccess(value)
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
function AV.SafeValue(fn, ...)
    if type(fn) ~= 'function' then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok or not AV.CanAccess(value) then
        return nil
    end
    return value
end

function AV.SafeBool(fn, ...)
    return AV.SafeValue(fn, ...) == true
end

-- Sends a possibly-secret number to a FontString with thousands separators.
function AV.SetNumberText(fontString, value)
    if value == nil then
        fontString:SetText('')
        return
    end
    if BreakUpLargeNumbers and pcall(function() fontString:SetText(BreakUpLargeNumbers(value)) end) then
        return
    end
    if not pcall(fontString.SetFormattedText, fontString, '%d', value) then
        fontString:SetText('')
    end
end

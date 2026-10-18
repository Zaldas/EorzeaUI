local _, EUI = ...

-- UnitHealthPercent(unit, usePredicted, curve) evaluates a curve engine-side on the secret
-- health fraction (0..1) and returns a colour Lua may forward to SetTextColor/SetVertexColor.

EUI.Curves = {}
local Curves = EUI.Curves

local STEP_EPSILON = 0.0001

-- thresholds = { { below = 0.25, color = '#..' }, ... } ascending; above the last uses defaultColor.
-- Curves interpolate linearly, so each step is two points EPSILON apart.
function Curves.Step(thresholds, defaultColor)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then
        return nil
    end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then
        return nil
    end

    local function add(x, hex)
        curve:AddPoint(x, CreateColor(EUI.Style.Color(hex)))
    end

    local built = pcall(function()
        local lower = 0
        for _, step in ipairs(thresholds) do
            add(lower, step.color)
            add(step.below - STEP_EPSILON, step.color)
            lower = step.below
        end
        add(lower, defaultColor)
        add(1, defaultColor)
    end)
    return built and curve or nil
end

-- Evaluates curve on unit's health and passes the colour to region[setter].
local function applyCurve(region, setter, unit, curve)
    if not curve then
        return
    end
    local ok, color = pcall(UnitHealthPercent, unit, true, curve)
    if not ok then
        EUI.LogOnce('curve:' .. setter, 'UnitHealthPercent for %s failed: %s', setter, tostring(color))
    elseif color and color.GetRGBA then
        pcall(region[setter], region, color:GetRGBA())
    end
end

function Curves.ApplyHealthColor(fontString, unit, curve)
    applyCurve(fontString, 'SetTextColor', unit, curve)
end

function Curves.ApplyHealthTint(texture, unit, curve)
    applyCurve(texture, 'SetVertexColor', unit, curve)
end

function Curves.SetHealthPercentText(fontString, unit)
    local scale = CurveConstants and CurveConstants.ScaleTo100
    if not scale then
        fontString:SetText('')
        return
    end
    local ok = pcall(function()
        fontString:SetText(string.format('%.0f%%', UnitHealthPercent(unit, true, scale)))
    end)
    if not ok then
        fontString:SetText('')
    end
end

local _, AV = ...

-- UnitHealthPercent(unit, usePredicted, curve) evaluates a curve engine-side on the secret
-- health fraction (0..1) and returns a colour Lua may forward to SetTextColor/SetVertexColor.

AV.Curves = {}
local Curves = AV.Curves

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
        curve:AddPoint(x, CreateColor(AV.Style.Color(hex)))
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

function Curves.ApplyHealthColor(fontString, unit, curve)
    if not curve then
        return
    end
    local ok, color = pcall(UnitHealthPercent, unit, true, curve)
    if ok and color and color.GetRGBA then
        pcall(function() fontString:SetTextColor(color:GetRGBA()) end)
    end
end

function Curves.ApplyHealthTint(texture, unit, curve)
    if not curve then
        return
    end
    local ok, color = pcall(UnitHealthPercent, unit, true, curve)
    if ok and color and color.GetRGBA then
        pcall(function() texture:SetVertexColor(color:GetRGBA()) end)
    end
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

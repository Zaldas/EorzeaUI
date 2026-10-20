local _, EUI = ...

-- The settings top bar's hex texture (canvas board "Top bar hex texture": Mosaic, Larger cells,
-- tilted, Subtle): a still grid of etched glyph tiles and five groups of cells that light in
-- turn. Art from tools/hexBarArt.py, the bar's left 620 x 48 units with the tilt and fade baked in.

EUI.Config = EUI.Config or {}
local Config = EUI.Config
local Style = EUI.Style

local WIDTH, HEIGHT = 620, 48
-- Each layer fills the top-left 1240 x 96 px of a 2048 x 128 texture.
local RIGHT, BOTTOM = 1240 / 2048, 96 / 128
local STRENGTH = 0.5
-- Each group brightens and fades over PERIOD seconds, the next starting a second later.
local GROUPS, PERIOD = 5, 5

-- window: the settings window. The layers draw between its panel fill and its rims, under the
-- header's icon and title.
function Config.CreateHexBar(window)
    local function layer(name, subLevel)
        local texture = window:CreateTexture(nil, 'BACKGROUND', nil, subLevel)
        texture:SetTexture(Style.AssetPath('settings/' .. name))
        texture:SetTexCoord(0, RIGHT, 0, BOTTOM)
        texture:SetPoint('TOPLEFT', 1, -1)
        texture:SetSize(WIDTH - 1, HEIGHT - 1)
        return texture
    end
    layer('hexBarBase', 5):SetAlpha(STRENGTH)
    local lit = {}
    for i = 1, GROUPS do
        lit[i] = layer('hexBarLit' .. i, 6)
        lit[i]:SetAlpha(0)
    end

    local driver = CreateFrame('Frame', nil, window)
    local clock = 0
    driver:SetScript('OnUpdate', function(_, elapsed)
        clock = clock + elapsed
        for i, texture in ipairs(lit) do
            local phase = (clock - (i - 1)) / PERIOD
            texture:SetAlpha(STRENGTH * (0.5 - 0.5 * math.cos(2 * math.pi * phase)))
        end
    end)
end

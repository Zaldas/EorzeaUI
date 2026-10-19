local _, EUI = ...

-- Minimap button through LibDBIcon: left-click opens the settings window, right-click locks or
-- unlocks the frames, left-drag moves it around the rim. LibDBIcon keeps its position in the
-- minimap table (minimapPos, hide, lock).

local Config = EUI.Config
local Settings = EUI.Settings
local Style = EUI.Style

local NAME = 'EorzeaUI'
local ICON = 'Interface\\AddOns\\EorzeaUI\\Media\\AddonIcon'
-- The blue tile inside AddonIcon's white frame (pixels 7..57 of 64); masked round for the ring.
local ICON_COORDS = { 7 / 64, 57 / 64, 7 / 64, 57 / 64 }

Settings.Declare('minimap', {})

local function showTooltip(tooltip)
    tooltip:AddLine(NAME)
    tooltip:AddLine('Left-click: settings', 1, 1, 1)
    tooltip:AddLine(EUI.EditMode.unlocked and 'Right-click: lock frames' or 'Right-click: unlock frames', 1, 1, 1)
    tooltip:AddLine('Drag: move this button', 0.7, 0.7, 0.7)
end

function Config.RegisterMinimapButton()
    local LibStub = _G.LibStub
    local ldb = LibStub and LibStub('LibDataBroker-1.1', true)
    local icon = LibStub and LibStub('LibDBIcon-1.0', true)
    if not (ldb and icon) then
        EUI.LogOnce('config:minimapButton', 'LibDataBroker or LibDBIcon missing; no minimap button')
        return
    end
    local object = ldb:NewDataObject(NAME, {
        type = 'launcher',
        icon = ICON,
        iconCoords = ICON_COORDS,
        OnTooltipShow = showTooltip,
        OnClick = EUI.Guard('minimap click', function(button, mouseButton)
            if not EUI.ready then
                return
            end
            if mouseButton == 'RightButton' then
                EUI.EditMode.SetUnlocked(not EUI.EditMode.unlocked)
                -- The tooltip is built on enter; rebuild it so the right-click line follows.
                local tooltip = icon.tooltip
                if tooltip and tooltip:IsOwned(button) then
                    tooltip:ClearLines()
                    showTooltip(tooltip)
                    tooltip:Show()
                end
            else
                Config.Toggle()
            end
        end),
    })
    if not object then
        return
    end
    icon:Register(NAME, object, Settings.Get('minimap'))
    local button = icon:GetMinimapButton(NAME)
    if button and button.icon then
        local mask = button:CreateMaskTexture()
        mask:SetAllPoints(button.icon)
        Style.SetAtlas(mask, 'CircleMask')
        pcall(mask.SetTexture, mask, mask:GetTexture(), 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
        button.icon:AddMaskTexture(mask)
    end
    local ring = Config.style and Config.style.ring
    if button and button.border and ring then
        button.border:SetDesaturated(true)
        button.border:SetVertexColor(Style.Color(ring))
    end
end

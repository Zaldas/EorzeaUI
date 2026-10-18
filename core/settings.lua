local _, EUI = ...

-- Saved settings (EorzeaUIDB) over DEFAULTS, read and written by dot-separated path
-- ('scale', 'positions.party'). Set calls the listeners registered for that exact path.

EUI.Settings = {}
local Settings = EUI.Settings

-- positions: Edit Mode anchors by frame key. colors: palette overrides by style, then palette
-- key (colors.azeroth.hp), applied when the style is built at login.
local DEFAULTS = {
    style = 'vanadiel',
    scale = 1,
    positions = {},
    colors = {},
}

local listeners = {}

local function copy(value)
    if type(value) ~= 'table' then
        return value
    end
    local out = {}
    for key, inner in pairs(value) do
        out[key] = copy(inner)
    end
    return out
end
Settings.Copy = copy

-- Fills keys missing from saved with defaults, recursing into tables both have.
local function fill(saved, defaults)
    for key, value in pairs(defaults) do
        if saved[key] == nil then
            saved[key] = copy(value)
        elseif type(value) == 'table' and type(saved[key]) == 'table' then
            fill(saved[key], value)
        end
    end
end

-- Returns the table holding path's last key, and that key; nil when a table on the way is
-- missing, unless create builds it.
local function locate(root, path, create)
    local parent, key = root, nil
    for part in path:gmatch('[^.]+') do
        if key then
            local inner = parent[key]
            if type(inner) ~= 'table' then
                if not create then
                    return nil
                end
                inner = {}
                parent[key] = inner
            end
            parent = inner
        end
        key = part
    end
    return parent, key
end

function Settings.Load()
    if type(EorzeaUIDB) ~= 'table' then
        EorzeaUIDB = {}
    end
    fill(EorzeaUIDB, DEFAULTS)
    EUI.db = EorzeaUIDB
end

-- Before Load, the default.
function Settings.Get(path)
    local parent, key = locate(EUI.db or DEFAULTS, path)
    if not parent then
        return nil
    end
    return parent[key]
end

function Settings.Default(path)
    local parent, key = locate(DEFAULTS, path)
    if not parent then
        return nil
    end
    return copy(parent[key])
end

-- value nil clears the path.
function Settings.Set(path, value)
    local parent, key = locate(EUI.db, path, true)
    parent[key] = value
    for _, fn in ipairs(listeners[path] or {}) do
        fn(value)
    end
end

function Settings.Reset(path)
    Settings.Set(path, Settings.Default(path))
end

-- fn(value) runs after each Set of path.
function Settings.OnChange(path, fn)
    listeners[path] = listeners[path] or {}
    table.insert(listeners[path], fn)
end

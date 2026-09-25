function widget:GetInfo()
    return {name = 'Dhubai weather sky', desc = 'Select the map panorama from MOSAIC time and rain',
        author = 'MOSAIC contributors', layer = 0, enabled = true}
end

local dayLength = 28800 -- same frame clock and noon offset as MOSAIC rain
local elapsed, current, wet = 0, nil, false
local loaded = {}

local function updateSky()
    local p = ((Spring.GetGameFrame() + dayLength * 0.5) % dayLength) / dayLength
    -- This is the rain renderer's actual local wetness, including /weatherman.
    local rain = WG.GetVehicleHeadlightWetness and WG.GetVehicleHeadlightWetness() or 0
    if rain >= 0.25 then wet = true elseif rain <= 0.10 then wet = false end
    local name
    if p < 0.25 or p >= 0.75 then
        -- Only one night panorama is currently available; it includes rain clouds.
        name = 'rainy-night'
    else
        name = wet and 'overcast-day' or 'clear-day'
    end
    if name == current then return end
    local path = 'maps/skyboxes/' .. name .. '.dds'
    -- TextureInfo loads the named texture before SetSkyBoxTexture looks it up.
    local info = gl.TextureInfo(path)
    if not info or not info.id or info.id == 0 then return end
    Spring.SetSkyBoxTexture(path)
    loaded[path], current = true, name
end

function widget:Initialize()
    local options = Spring.GetMapOptions() or {}
    if (options.dhubai_sky and options.dhubai_sky ~= 'automatic')
        or not Spring.SetSkyBoxTexture then
        widgetHandler:RemoveWidget(self)
        return
    end
    updateSky()
end

function widget:Update(dt)
    elapsed = elapsed + dt
    if elapsed < 1 then return end
    elapsed = 0
    updateSky()
end

function widget:Shutdown()
    if not current then return end
    Spring.SetSkyBoxTexture('') -- release the active reference before deleting textures
    for path in pairs(loaded) do gl.DeleteTexture(path) end
end

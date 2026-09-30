-- Atmospheric renderer moved from MOSAIC's disabled Volumetric Clouds widget.
-- Original: Anarchid, consulted and optimized by jK, GNU GPL v2 or later.
function widget:GetInfo()
    return {name = 'Dhubai volumetric weather', version = 10,
        desc = 'Occasional dawn fog, city smog and desert sandstorms',
        author = 'Anarchid, jK, MOSAIC contributors', license = 'GNU GPL v2 or later',
        -- MOSAIC draws higher layers first: after radiance (-9), before rain (-13).
        layer = -12, enabled = true}
end

local base = 'LuaUI/Widgets_Map/'
local Weather = VFS.Include(base .. 'Include/dhubai_weather.lua', nil, VFS.MAP)
local controller = Weather.New(Game.mapChecksum)
-- gl.Texture has no VFS.MAP argument: keep named GPU assets in a map-specific path.
local noiseTexture = 'LuaUI/Images/Dhubai/Weather/worley_noise_128.dds'
local shader, depthTexture, fogTexture
local barrierShader, barrierTexture
local barrierDirty = true
local uniforms = {}
local vsx, vsy, vpx, vpy
local mode, strength, profile, phase = 'clear', 0, nil, 0
local forced = 'automatic'
local opacityMult = 1
local offsetX, offsetZ, lastFrame = 0, 0, nil
local ready = false
local api
local radianceEnabled, radiance = true, nil

local function remove(reason)
    Spring.Echo('Dhubai weather: ' .. reason)
    widgetHandler:RemoveWidget(widget)
end

local function deleteTargets()
    if depthTexture then gl.DeleteTexture(depthTexture); depthTexture = nil end
    if fogTexture then gl.DeleteTexture(fogTexture); fogTexture = nil end
end

function widget:ViewResize()
    if not shader then return end
    vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
    vsx, vsy = math.max(1, vsx), math.max(1, vsy)
    vpx, vpy = vpx or 0, vpy or 0
    deleteTargets()
    depthTexture = gl.CreateTexture(vsx, vsy, {
        format = GL.DEPTH_COMPONENT24 or 0x81A6,
        min_filter = GL.NEAREST, mag_filter = GL.NEAREST,
        wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
    })
    fogTexture = gl.CreateTexture(math.max(1, math.floor(vsx/4)), math.max(1, math.floor(vsy/4)), {
        min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE, fbo = true,
    })
    if not depthTexture or not fogTexture then
        ready = false
        remove('could not allocate the depth/fog targets')
    end
end

local function updateWeather(frame)
    local wetness = WG.GetVehicleHeadlightWetness and WG.GetVehicleHeadlightWetness() or 0
    mode, strength, profile, phase = controller.Evaluate(frame, wetness, forced)
end

function widget:Initialize()
    forced = (Spring.GetMapOptions() or {}).dhubai_weather or 'automatic'
    if forced == 'off' then widgetHandler:RemoveWidget(self); return end
    if WG.DhubaiWeather ~= nil then
        remove('another widget already owns WG.DhubaiWeather'); return
    end
    if not gl.CreateShader or not gl.RenderToTexture or not gl.CopyToTexture then
        remove('GLSL and render-to-texture support are required'); return
    end
    local vertex = VFS.LoadFile(base .. 'Shaders/fogShader.vert', VFS.MAP)
    local fragment = VFS.LoadFile(base .. 'Shaders/fogShader.frag', VFS.MAP)
    local barrierFragment = VFS.LoadFile(base .. 'Shaders/sandBarrier.frag', VFS.MAP)
    if not vertex or not fragment or not barrierFragment or not VFS.FileExists(noiseTexture, VFS.MAP) then
        remove('map shader or 3D noise texture missing'); return
    end
    shader = gl.CreateShader({vertex = vertex, fragment = fragment,
        uniformInt = {depthtex = 0, noise3dtex = 1, radianceTex = 2,
            heightEnvelopeTex = 3, occupancyTex = 4, headlightTex = 5, terrainHeightTex = 6, sandBarrierTex = 7,
            zeroToOne = (Platform and Platform.glSupportClipSpaceControl) and 1 or 0}})
    if not shader then remove('shader compilation failed: ' .. tostring(gl.GetShaderLog())); return end
    for _, name in ipairs({'viewProjectionInv', 'offset', 'sundir', 'suncolor', 'fogColor',
        'fogBounds', 'noiseScale', 'extinction', 'opacity', 'strength', 'weatherKind',
        'eventPhase', 'mapSize', 'time', 'zeroToOne', 'radianceActive',
        'radianceStrength', 'headlightActive', 'headlightIntensity', 'groundWaveBounds'}) do
        uniforms[name] = gl.GetUniformLocation(shader, name)
    end
    barrierShader = gl.CreateShader({vertex = vertex, fragment = barrierFragment,
        uniformInt = {terrainHeightTex = 6}})
    if not barrierShader then remove('sand barrier shader compilation failed: ' .. tostring(gl.GetShaderLog())); return end
    barrierTexture = gl.CreateTexture(math.floor(Game.mapSizeX/8), 1, {
        format = GL.R32F or 0x822E, fbo = true,
        min_filter = GL.NEAREST, mag_filter = GL.NEAREST,
        wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
    })
    if not barrierTexture then remove('could not allocate sand barrier'); return end
    self:ViewResize()
    if not depthTexture or not fogTexture then return end
    ready = true
    updateWeather(Spring.GetGameFrame())
    lastFrame = Spring.GetGameFrame()
    api = {
        GetState = function() return mode, strength, forced end,
        SetMode = function(value)
            if value ~= 'automatic' and value ~= 'off' and not Weather.profiles[value] then return false end
            forced = value
            updateWeather(Spring.GetGameFrame())
            return true
        end,
    }
    WG.DhubaiWeather = api
end

function widget:GetConfigData()
    return {opacityMult = opacityMult, radianceEnabled = radianceEnabled}
end

function widget:SetConfigData(data)
    local value = data and tonumber(data.opacityMult)
    if value and value == value then opacityMult = math.max(0, math.min(1.5, value)) end
    if data and data.radianceEnabled ~= nil then radianceEnabled = data.radianceEnabled ~= false end
end

function widget:TextCommand(command)
    if command ~= 'dhubaiweather' and command:sub(1, 14) ~= 'dhubaiweather ' then return false end
    if command == 'dhubaiweather light on' or command == 'dhubaiweather light off' then
        radianceEnabled = command == 'dhubaiweather light on'
        Spring.Echo('Dhubai fog radiance: ' .. (radianceEnabled and 'ON' or 'OFF'))
        return true
    end
    local value = command:match('^dhubaiweather%s+(%S+)%s*$')
    if value and api.SetMode(value) then
        Spring.Echo('Dhubai weather: ' .. value .. ' (local visual preview)')
    else
        Spring.Echo('Dhubai weather: ' .. mode .. '; /dhubaiweather automatic|fog|smog|sandstorm|off; light on|off')
    end
    return true
end

function widget:GameFrame(frame)
    updateWeather(frame)
    local delta = math.max(0, math.min(30, frame-(lastFrame or frame)))
    lastFrame = frame
    if not profile then return end
    local wx, _, wz = Spring.GetWind()
    -- Simulation frames, not wall time: pause and game-speed changes stay correct.
    offsetX = offsetX-(wx or 0)*profile.speed*delta
    offsetZ = offsetZ-(wz or 0)*profile.speed*delta
end

local function renderFog()
    gl.Texture(0, depthTexture)
    gl.Texture(1, noiseTexture)
    -- Borrowed handles are looked up each draw, never cached across reloads or deleted.
    gl.Texture(2, radiance and radiance.texture or depthTexture)
    gl.Texture(3, radiance and radiance.heights or depthTexture)
    gl.Texture(4, radiance and radiance.occupancy or depthTexture)
    gl.Texture(5, radiance and radiance.headlights or depthTexture)
    gl.Texture(6, '$heightmap')
    gl.Texture(7, barrierTexture)
    gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
    for slot = 2, 7 do gl.Texture(slot, false) end
    gl.Texture(1, false)
    gl.Texture(0, false)
end

function widget:UnsyncedHeightMapUpdate()
    barrierDirty = true
end

local function renderBarrier()
    gl.Texture(6, '$heightmap')
    gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
    gl.Texture(6, false)
end

function widget:DrawWorld()
    if not ready then return end
    local frame = Spring.GetGameFrame() + (Spring.GetFrameTimeOffset and Spring.GetFrameTimeOffset() or 0)
    updateWeather(frame)
    if not profile or strength*opacityMult <= 0.001 then return end
    radiance = nil
    if radianceEnabled and type(WG.GetMosaicFogRadiance) == 'function' then
        local field = WG.GetMosaicFogRadiance()
        -- No unbounded fallback to a flat rain/ground field when height data is absent.
        if type(field) == 'table' and field.version == 1 and field.texture and field.heights
            and field.occupancy and type(field.strength) == 'number' and field.strength > 0 then
            radiance = field
        end
    end
    -- DrawWorld runs after opaque units: the same scene depth clips ground AND models.
    gl.PushAttrib(GL.ALL_ATTRIB_BITS)
    gl.CopyToTexture(depthTexture, 0, 0, vpx, vpy, vsx, vsy)
    gl.DepthTest(false)
    gl.DepthMask(false)
    gl.Blending(false)
    gl.Color(1, 1, 1, 1)
    if mode == 'sandstorm' and barrierDirty then
        gl.UseShader(barrierShader)
        gl.RenderToTexture(barrierTexture, renderBarrier)
        barrierDirty = false
    end
    gl.UseShader(shader)
    gl.UniformMatrix(uniforms.viewProjectionInv, 'viewprojectioninverse')
    gl.Uniform(uniforms.offset, offsetX, 0, offsetZ)
    gl.Uniform(uniforms.sundir, gl.GetSun('pos'))
    gl.Uniform(uniforms.suncolor, gl.GetSun('diffuse'))
    gl.Uniform(uniforms.fogColor, unpack(profile.color))
    local bottom, ceiling = profile.bottom, profile.height
    if mode == 'sandstorm' then
        local initialMin, initialMax, currentMin, currentMax = Spring.GetGroundExtremes()
        local groundMin = math.max(0, currentMin or initialMin)
        local groundMax = math.max(groundMin, currentMax or initialMax) + 64
        gl.Uniform(uniforms.groundWaveBounds, groundMin, groundMax)
        bottom, ceiling = math.min(bottom, groundMin), math.max(ceiling, groundMax)
    end
    gl.Uniform(uniforms.fogBounds, bottom, profile.fade, ceiling)
    gl.Uniform(uniforms.noiseScale, 1/profile.scale)
    gl.Uniform(uniforms.extinction, profile.extinction)
    gl.Uniform(uniforms.opacity, math.min(0.92, profile.opacity*opacityMult))
    gl.Uniform(uniforms.strength, strength)
    gl.UniformInt(uniforms.weatherKind, profile.kind)
    gl.Uniform(uniforms.eventPhase, phase)
    gl.Uniform(uniforms.mapSize, Game.mapSizeX, Game.mapSizeZ)
    gl.Uniform(uniforms.time, frame/(Game.gameSpeed or 30)*profile.speed)
    gl.UniformInt(uniforms.radianceActive, radiance and 1 or 0)
    gl.Uniform(uniforms.radianceStrength, radiance and radiance.strength or 0)
    gl.UniformInt(uniforms.headlightActive, radiance and radiance.headlights and 1 or 0)
    gl.Uniform(uniforms.headlightIntensity, radiance and radiance.headlightIntensity or 0)
    gl.RenderToTexture(fogTexture, renderFog)
    radiance = nil
    gl.UseShader(0)

    -- The raymarch returns premultiplied colour; do not multiply alpha twice.
    gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
    gl.MatrixMode(GL.MODELVIEW); gl.PushMatrix(); gl.LoadIdentity()
    gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
    gl.Texture(0, fogTexture)
    gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
    gl.Texture(0, false)
    gl.PopMatrix()
    gl.MatrixMode(GL.MODELVIEW); gl.PopMatrix()
    gl.PopAttrib()
end

function widget:Shutdown()
    ready = false
    if WG.DhubaiWeather == api then WG.DhubaiWeather = nil end
    deleteTargets()
    if barrierTexture then gl.DeleteTexture(barrierTexture); barrierTexture = nil end
    if barrierShader then gl.DeleteShader(barrierShader); barrierShader = nil end
    if shader then gl.DeleteShader(shader); shader = nil end
    -- Noise belongs to the map and can be shared by other effects.
end

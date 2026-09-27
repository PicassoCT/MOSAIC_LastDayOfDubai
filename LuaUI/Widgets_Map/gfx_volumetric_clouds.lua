-- Atmospheric renderer moved from MOSAIC's disabled Volumetric Clouds widget.
-- Original: Anarchid, consulted and optimized by jK, GNU GPL v2 or later.
function widget:GetInfo()
    return {name = 'Dhubai volumetric weather', version = 7,
        desc = 'Occasional dawn fog, city smog and desert sandstorms',
        author = 'Anarchid, jK, MOSAIC contributors', license = 'GNU GPL v2 or later',
        layer = -1, enabled = true}
end

local base = 'LuaUI/Widgets_Map/'
local Weather = VFS.Include(base .. 'Include/dhubai_weather.lua', nil, VFS.MAP)
local controller = Weather.New(Game.mapChecksum)
local noiseTexture = 'LuaUI/images/noisetextures/worley_rgbnorm_01_asum_128_v1.dds'
local shader, depthTexture, fogTexture
local uniforms = {}
local vsx, vsy, vpx, vpy
local mode, strength, profile, phase = 'clear', 0, nil, 0
local forced = 'automatic'
local opacityMult = 1
local offsetX, offsetZ, lastFrame = 0, 0, nil
local ready = false
local api

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
    if not gl.CreateShader or not gl.RenderToTexture or not gl.CopyToTexture then
        remove('GLSL and render-to-texture support are required'); return
    end
    local vertex = VFS.LoadFile(base .. 'Shaders/fogShader.vert', VFS.MAP)
    local fragment = VFS.LoadFile(base .. 'Shaders/fogShader.frag', VFS.MAP)
    if not vertex or not fragment or not VFS.FileExists(noiseTexture, VFS.MAP) then
        remove('map shader or 3D noise texture missing'); return
    end
    shader = gl.CreateShader({vertex = vertex, fragment = fragment,
        uniformInt = {depthtex = 0, noise3dtex = 1,
            zeroToOne = (Platform and Platform.glSupportClipSpaceControl) and 1 or 0}})
    if not shader then remove('shader compilation failed: ' .. tostring(gl.GetShaderLog())); return end
    for _, name in ipairs({'viewProjectionInv', 'offset', 'sundir', 'suncolor', 'fogColor',
        'fogBounds', 'noiseScale', 'extinction', 'opacity', 'strength', 'weatherKind',
        'eventPhase', 'mapSize', 'time', 'zeroToOne'}) do
        uniforms[name] = gl.GetUniformLocation(shader, name)
    end
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
    return {opacityMult = opacityMult}
end

function widget:SetConfigData(data)
    local value = data and tonumber(data.opacityMult)
    if value and value == value then opacityMult = math.max(0, math.min(1.5, value)) end
end

function widget:TextCommand(command)
    if command ~= 'dhubaiweather' and command:sub(1, 14) ~= 'dhubaiweather ' then return false end
    local value = command:match('^dhubaiweather%s+(%S+)%s*$')
    if value and api.SetMode(value) then
        Spring.Echo('Dhubai weather: ' .. value .. ' (local visual preview)')
    else
        Spring.Echo('Dhubai weather: ' .. mode .. '; /dhubaiweather automatic|fog|smog|sandstorm|off')
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
    gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
    gl.Texture(1, false)
    gl.Texture(0, false)
end

function widget:DrawWorld()
    if not ready then return end
    local frame = Spring.GetGameFrame() + (Spring.GetFrameTimeOffset and Spring.GetFrameTimeOffset() or 0)
    updateWeather(frame)
    if not profile or strength*opacityMult <= 0.001 then return end
    -- DrawWorld runs after opaque units: the same scene depth clips ground AND models.
    gl.PushAttrib(GL.ALL_ATTRIB_BITS)
    gl.CopyToTexture(depthTexture, 0, 0, vpx, vpy, vsx, vsy)
    gl.DepthTest(false)
    gl.DepthMask(false)
    gl.Blending(false)
    gl.Color(1, 1, 1, 1)
    gl.UseShader(shader)
    gl.UniformMatrix(uniforms.viewProjectionInv, 'viewprojectioninverse')
    gl.Uniform(uniforms.offset, offsetX, 0, offsetZ)
    gl.Uniform(uniforms.sundir, gl.GetSun('pos'))
    gl.Uniform(uniforms.suncolor, gl.GetSun('diffuse'))
    gl.Uniform(uniforms.fogColor, unpack(profile.color))
    gl.Uniform(uniforms.fogBounds, profile.bottom, profile.fade, profile.height)
    gl.Uniform(uniforms.noiseScale, 1/profile.scale)
    gl.Uniform(uniforms.extinction, profile.extinction)
    gl.Uniform(uniforms.opacity, math.min(0.92, profile.opacity*opacityMult))
    gl.Uniform(uniforms.strength, strength)
    gl.UniformInt(uniforms.weatherKind, profile.kind)
    gl.Uniform(uniforms.eventPhase, phase)
    gl.Uniform(uniforms.mapSize, Game.mapSizeX, Game.mapSizeZ)
    gl.Uniform(uniforms.time, frame/(Game.gameSpeed or 30)*profile.speed)
    gl.RenderToTexture(fogTexture, renderFog)
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
    if shader then gl.DeleteShader(shader); shader = nil end
    -- Noise belongs to the map and can be shared by other effects.
end

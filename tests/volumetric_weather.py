"""Production scheduler and mocked Spring/OpenGL lifecycle checks; requires lupa."""
from pathlib import Path
from collections import Counter
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
weather = lua.execute((ROOT/'LuaUI/Widgets_Map/Include/dhubai_weather.lua').read_text())
controller = weather.New(70427)
counts = Counter()
active = 0
samples = 0
for day in range(1, 501):
    found = set()
    previous = 0
    for tick in range(0, 28800, 30):
        frame = day*28800+tick-14400
        mode, strength, profile, phase = controller.Evaluate(frame, 0, 'automatic')
        assert 0 <= strength <= 1
        assert abs(strength-previous) < 0.075, (day, mode, 'abrupt fade')
        previous = strength
        if strength > 0:
            found.add(mode)
            active += 1
            if mode == 'fog':
                assert 0.18 < tick/28800 < 0.36, 'fog outside dawn'
            wet = controller.Evaluate(frame, 1, 'automatic')
            assert wet[1] == 0 if mode in ('smog', 'sandstorm') else wet[1] <= strength
        samples += 1
    assert not {'smog', 'sandstorm'}.issubset(found), 'overlapping afternoon weather'
    counts.update(found)
assert 180 < counts['fog'] < 300 and 90 < counts['smog'] < 180 and 40 < counts['sandstorm'] < 100, counts
assert active/samples < 0.2, 'weather is not occasional'
for frame in [0, 17000, 22000, 46000, 88000, 180000]:
    a = controller.Evaluate(frame, 0.1, 'automatic')
    b = weather.New(70427).Evaluate(frame, 0.1, 'automatic')
    assert (a[0], a[1], a[3]) == (b[0], b[1], b[3]), 'reload changed event'
for name in ['fog', 'smog', 'sandstorm']:
    assert controller.Evaluate(0, 1, name)[0:2] == (name, 1)
assert controller.Evaluate(0, 0, 'off')[1] == 0
print('PASS scheduler:', dict(counts), 'active fraction', round(active/samples, 3))

# Compile every shipped Lua file; mocked renderer executes actual map-only includes.
for path in [*ROOT.glob('LuaUI/Widgets_Map/**/*.lua'), ROOT/'mapoptions.lua']:
    lua.execute('assert(loadstring(...))', path.read_text())

def new_widget(fail_texture=False, fail_shader=False, option='automatic', collision=False):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().read_file = lambda path: (ROOT/path).read_text() if (ROOT/path).is_file() else None
    runtime.globals().file_exists = lambda path: (ROOT/path).is_file()
    runtime.globals().failTexture = fail_texture
    runtime.globals().failShader = fail_shader
    runtime.globals().option = option
    runtime.globals().collision = collision
    runtime.execute('''
        widget = {}; WG = {}; textures = {}; bound = {}; shaderLive = {}; activeShader = 0
        frame = 0; rain = 0; copies = 0; draws = 0; removes = 0; nextID = 1
        attribStack = 0; matrixStack = 0; viewX = 801; viewY = 603
        Game = {mapChecksum = 70427, mapSizeX = 8192, mapSizeZ = 8192, gameSpeed = 30}
        Platform = {glSupportClipSpaceControl = true}
        GL = setmetatable({}, {__index=function(_, k) return k end})
        VFS = {MAP = 'map'}
        function VFS.LoadFile(path, archive) assert(archive == VFS.MAP); return read_file(path) end
        function VFS.Include(path, env, archive) return assert(loadstring(VFS.LoadFile(path, archive)))() end
        function VFS.FileExists(path, archive) assert(archive == VFS.MAP); return file_exists(path) end
        Spring = {
            GetMapOptions=function() return {dhubai_weather=option} end,
            GetGameFrame=function() return frame end, GetFrameTimeOffset=function() return 0 end,
            GetViewGeometry=function() return viewX, viewY, 10, 20 end,
            GetWind=function() return 2, 0, 3 end, Echo=function() end,
        }
        WG.GetVehicleHeadlightWetness=function() return rain end
        collisionOwner = {marker = 'existing owner'}
        if collision then WG.DhubaiWeather = collisionOwner end
        widgetHandler = {RemoveWidget=function(_, w) removes=removes+1; w:Shutdown() end}
        gl = {
            CreateShader=function(source)
                assert(source.vertex and source.fragment)
                if failShader then return nil end
                shaderLive[99]=true; return 99
            end,
            DeleteShader=function(id) assert(shaderLive[id]); shaderLive[id]=nil end,
            GetShaderLog=function() return 'test failure' end,
            GetUniformLocation=function(_, name) return name end,
            CreateTexture=function(w,h,opts)
                assert(w%1==0 and h%1==0 and w>0 and h>0)
                if failTexture then return nil end
                local id=nextID; nextID=nextID+1; textures[id]=true; return id
            end,
            DeleteTexture=function(id) assert(textures[id]); textures[id]=nil end,
            CopyToTexture=function(id, x,y, vx,vy,w,h)
                assert(textures[id] and vx==10 and vy==20); copies=copies+1
            end,
            Texture=function(unit, tex) bound[unit]=tex end,
            UseShader=function(id) activeShader=id end,
            RenderToTexture=function(id, fn) assert(textures[id]); fn() end,
            TexRect=function()
                if activeShader~=0 then
                    assert(textures[bound[0]], 'depth unbound before draw')
                    assert(type(bound[1])=='string' and file_exists(bound[1]), 'noise unbound before draw')
                else assert(textures[bound[0]], 'fog target missing') end
                draws=draws+1
            end,
            PushAttrib=function() attribStack=attribStack+1 end,
            PopAttrib=function() attribStack=attribStack-1 end,
            PushMatrix=function() matrixStack=matrixStack+1 end,
            PopMatrix=function() matrixStack=matrixStack-1 end,
            GetSun=function(what) if what=='pos' then return 0,1,0 end; return 1,1,1 end,
        }
        for _, name in ipairs({'DepthTest','DepthMask','Blending','Color','UniformMatrix',
            'Uniform','UniformInt','MatrixMode','LoadIdentity'}) do gl[name]=function() end end
    ''')
    runtime.execute((ROOT/'LuaUI/Widgets_Map/gfx_dhubai_volumetric_weather.lua').read_text())
    runtime.execute('widget:Initialize()')
    return runtime

runtime = new_widget()
runtime.execute('''
    assert(WG.DhubaiWeather)
    assert(widget:TextCommand('dhubaiweather off'))
    widget:DrawWorld(); assert(copies==0 and draws==0, 'clear weather does GPU work')
    assert(not widget:TextCommand('dhubaiweathering fog'))
    for _, name in ipairs({'fog','smog','sandstorm'}) do
        widget:TextCommand('dhubaiweather '..name)
        widget:GameFrame(frame+1); widget:DrawWorld()
        assert(WG.DhubaiWeather.GetState()==name)
        assert(activeShader==0 and attribStack==0 and matrixStack==0, 'GL state leaked')
    end
    assert(copies==3 and draws==6)
    assert(not WG.DhubaiWeather.SetMode('invalid'))
    viewX=1; viewY=1; widget:ViewResize(); widget:DrawWorld()
    local count=0; for _ in pairs(textures) do count=count+1 end; assert(count==2)
    widget:Shutdown()
    assert(not WG.DhubaiWeather and next(textures)==nil and next(shaderLive)==nil)
''')
for fail_texture, fail_shader, option in [(True,False,'automatic'),(False,True,'automatic'),(False,False,'off')]:
    r = new_widget(fail_texture, fail_shader, option)
    r.execute('assert(removes==1 and not WG.DhubaiWeather and next(textures)==nil and next(shaderLive)==nil)')

r = new_widget(collision=True)
r.execute('assert(removes==1 and WG.DhubaiWeather==collisionOwner and next(textures)==nil and next(shaderLive)==nil)')
r = new_widget()
r.execute('WG.DhubaiWeather=collisionOwner; widget:Shutdown(); assert(WG.DhubaiWeather==collisionOwner)')

# Sky integration uses its production widget, including static-sky opt-out.
runtime.execute('''
    widget={}; skyMode='sandstorm'; skyStrength=1; skyOption='automatic'; selectedSky=nil
    frame=4000; rain=0
    WG.DhubaiWeather={GetState=function() return skyMode,skyStrength end}
    Spring.GetMapOptions=function() return {dhubai_sky=skyOption} end
    Spring.SetSkyBoxTexture=function(path) selectedSky=path end
    gl.TextureInfo=function() return {id=1} end
    gl.DeleteTexture=function() end
''')
runtime.execute((ROOT/'LuaUI/Widgets_Map/gfx_dhubai_sky.lua').read_text())
runtime.execute('''
    widget:Initialize(); assert(selectedSky=='maps/skyboxes/sunset-sandstorm.dds')
    skyStrength=0.2; widget:Update(1); assert(selectedSky=='maps/skyboxes/sunset-sandstorm.dds')
    skyStrength=0.1; widget:Update(1); assert(selectedSky=='maps/skyboxes/clear-day.dds')
    rain=1; widget:Update(1); assert(selectedSky=='maps/skyboxes/overcast-day.dds')
    frame=9000; widget:Update(1); assert(selectedSky=='maps/skyboxes/rainy-night.dds')
    WG.DhubaiWeather=true; widget:Update(1) -- malformed/foreign API must not crash the sky
    widget:Shutdown()
''')
runtime.execute("widget={}; selectedSky=nil; skyOption='original'")
runtime.execute((ROOT/'LuaUI/Widgets_Map/gfx_dhubai_sky.lua').read_text())
runtime.execute('widget:Initialize(); assert(selectedSky==nil)')
print('PASS Lua syntax, texture bindings, clear skip, resize, cleanup/failures, commands, sky selection')

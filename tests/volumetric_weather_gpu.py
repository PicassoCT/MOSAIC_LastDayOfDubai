"""Compile/render production shaders and map 3D noise using EGL/llvmpipe.
MESA_GL_VERSION_OVERRIDE=3.3COMPAT python tests/volumetric_weather_gpu.py [--preview PATH]
Dependencies: moderngl, numpy, lupa; Pillow only for --preview.
"""
from pathlib import Path
import ctypes
import sys
import numpy as np
import moderngl
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
ctx = moderngl.create_standalone_context(backend='egl', require=330)
shader_root = ROOT/'LuaUI/Widgets_Map/Shaders'
program = ctx.program(vertex_shader=(shader_root/'fogShader.vert').read_text(),
                      fragment_shader=(shader_root/'fogShader.frag').read_text())
gl = ctypes.CDLL('libGL.so.1')
gl.glUseProgram.argtypes = [ctypes.c_uint]
gl.glBegin.argtypes = [ctypes.c_uint]
gl.glVertex2f.argtypes = [ctypes.c_float, ctypes.c_float]
gl.glTexCoord2f.argtypes = [ctypes.c_float, ctypes.c_float]
w, h = 320, 240
output = ctx.texture((w,h), 4, dtype='f4')
fbo = ctx.framebuffer([output]); fbo.use()
depth_tex = ctx.texture((w,h), 1, dtype='f4'); depth_tex.use(0)
depth_tex.filter = (moderngl.NEAREST, moderngl.NEAREST)
# This map's DDS is a single-level 128^3 uncompressed RGBA volume (not generated test noise).
noise_bytes = (ROOT/'LuaUI/Images/Dhubai/Weather/worley_noise_128.dds').read_bytes()
assert len(noise_bytes) == 128+128**3*4
noise = ctx.texture3d((128,128,128), 4, noise_bytes[128:]); noise.use(1)
noise.filter = (moderngl.LINEAR, moderngl.LINEAR)
for n, v in dict(depthtex=0,noise3dtex=1,zeroToOne=0,offset=(0,0,0),sundir=(0.3,0.6,-0.4),
                 suncolor=(1,0.92,0.78),strength=1,eventPhase=0.5,mapSize=(8192,8192),time=15).items():
    program[n].value = v
weather = LuaRuntime(unpack_returned_tuples=True).execute(
    (ROOT/'LuaUI/Widgets_Map/Include/dhubai_weather.lua').read_text())

def profile(name):
    p = weather.profiles[name]
    values = dict(fogColor=tuple(p.color[i] for i in (1,2,3)),
                  fogBounds=(p.bottom,p.fade,p.height), noiseScale=1/p.scale,
                  extinction=p.extinction, opacity=p.opacity, weatherKind=p.kind)
    for n,v in values.items(): program[n].value = v

def normalize(v): return v/np.linalg.norm(v)

def camera(eye=(4096,650,7000), target=(4096,80,2500), zero=False, ortho=False, foreground=True):
    eye, target = np.array(eye,dtype=float),np.array(target,dtype=float)
    forward = normalize(target-eye); right = normalize(np.cross(forward,[0,1,0])); up=np.cross(right,forward)
    view=np.eye(4); view[:3,:3]=np.stack([right,up,-forward]); view[:3,3]=-view[:3,:3]@eye
    near,far=10.,20000.
    if ortho:
        proj=np.diag([1/3200,1/2400,-2/(far-near),1.]);proj[2,3]=-(far+near)/(far-near)
    else:
        f=1/np.tan(np.deg2rad(55)/2)
        proj=np.array([[f/(w/h),0,0,0],[0,f,0,0],[0,0,-(far+near)/(far-near),-2*far*near/(far-near)],[0,0,-1,0]])
    if zero: proj[2]=(proj[2]+proj[3])*0.5
    vp=proj@view;inv=np.linalg.inv(vp)
    program['viewProjectionInv'].write(inv.astype('f4').T.tobytes());program['zeroToOne'].value=int(zero)
    x,y=np.meshgrid((np.arange(w)+.5)/w*2-1,(np.arange(h)+.5)/h*2-1)
    def unproject(z):
        p=np.stack([x,y,np.full_like(x,z),np.ones_like(x)],axis=-1)@inv.T
        return p[...,:3]/p[...,3:]
    origin=unproject(0 if zero else -1);far_pos=unproject(1)
    direction=far_pos-origin;direction/=np.linalg.norm(direction,axis=-1,keepdims=True)
    with np.errstate(divide='ignore',invalid='ignore'):
        t=np.where(direction[...,1]<0,(40-origin[...,1])/direction[...,1],np.inf)
    t=np.where(t>0,t,np.inf)
    base=np.zeros((h,w,3));base[:]=(.36,.46,.55)
    base[np.isfinite(t)]=(.30,.28,.23)
    if foreground:
        for center,size,color in [((3300,190,5000),(250,150,250),(.32,.33,.35)),
                                  ((4500,330,4200),(250,290,220),(.24,.28,.30)),
                                  ((5200,150,3000),(500,110,300),(.41,.40,.35))]:
            center=np.array(center);size=np.array(size)
            with np.errstate(divide='ignore',invalid='ignore'):
                a=(center-size-origin)/direction;b=(center+size-origin)/direction
            start=np.maximum(np.minimum(a,b).max(axis=-1),0);end=np.maximum(a,b).min(axis=-1)
            hit=(start<end)&(start<t)
            t[hit]=start[hit];base[hit]=color
    pos=origin+direction*np.minimum(t,far)[...,None]
    clip=np.concatenate([pos,np.ones((h,w,1))],axis=-1)@vp.T
    depth=clip[...,2]/clip[...,3]
    if not zero:depth=depth*.5+.5
    depth=np.where(np.isfinite(t),depth,1)
    depth_tex.write(np.clip(depth,0,1).astype('f4').tobytes())
    return base

def render(**kwargs):
    for n,v in kwargs.items():program[n].value=v
    fbo.clear();gl.glUseProgram(program.glo);gl.glBegin(7)
    for x,y,u,v in [(-1,-1,0,0),(1,-1,1,0),(1,1,1,1),(-1,1,0,1)]:
        gl.glTexCoord2f(u,v);gl.glVertex2f(x,y)
    gl.glEnd();gl.glUseProgram(0)
    assert ctx.error=='GL_NO_ERROR',ctx.error
    image=np.frombuffer(output.read(),dtype='f4').reshape(h,w,4).copy()
    assert np.isfinite(image).all(), 'non-finite raymarch'
    assert image[...,3].min()>=0 and image[...,3].max()<=.93
    return image

base=camera();previews=[]
for name in ['fog','smog','sandstorm']:
    profile(name);a=render()
    assert a[...,3].sum()>100, name+' is invisible'
    assert a[...,3].max()<=weather.profiles[name].opacity+1e-6
    assert np.array_equal(a,render()),'paused fog changes'
    assert render(strength=0).max()==0, 'clear weather visible'
    render(strength=1)
    assert np.abs(a-render(time=50)).sum()>1, 'turbulence does not move'
    a=render(time=15);previews.append((name,base,a))
    camera(zero=True);b=render()
    assert np.allclose(a,b,atol=.007), (name,'depth convention mismatch',np.abs(a-b).max())
    camera(ortho=True);assert render()[...,3].sum()>50,'orthographic invisible'
    camera(eye=(4096,75,5000),target=(4096,76,1000));assert render()[...,3].sum()>50,'inside fog invisible'
    camera(eye=(4096,75,5000),target=(4096,75,1000));render() # exactly horizontal rays
    camera(eye=(4096,1500,5000),target=(4096,6500,1000));assert render().max()==0,'sky above layer filled'
    camera();depth_tex.write(np.zeros((h,w),dtype='f4').tobytes());assert render().max()==0,'foreground leak'
    camera()
profile('sandstorm');early=render(eventPhase=.1);late=render(eventPhase=.6)
assert late[...,3].sum()>early[...,3].sum()*1.1,'dust front does not advance'
render(eventPhase=.5)
profile('smog');day=render();night=render(sundir=(.3,-.6,-.4))
assert night[...,:3].sum()<day[...,:3].sum()*.4,'smog glows white at night'
# Bounded local light must scatter at the source's world height, not form columns.
field_size=64
radiance_data=np.zeros((field_size,field_size,3),dtype='f4');radiance_data[:]=(2,.02,.01)
height_data=np.zeros((field_size,field_size,4),dtype='f4')
occupancy_data=np.zeros((field_size,field_size,1),dtype='f4')
headlight_data=np.zeros((field_size,field_size,3),dtype='f4')
fields=[]
for slot,data in [(2,radiance_data),(3,height_data),(4,occupancy_data),(5,headlight_data)]:
    tex=ctx.texture((field_size,field_size),data.shape[-1],data.tobytes(),dtype='f4')
    tex.filter=(moderngl.NEAREST,moderngl.NEAREST);tex.use(slot);fields.append(tex)
for n,v in dict(radianceTex=2,heightEnvelopeTex=3,occupancyTex=4,headlightTex=5,
                radianceStrength=2,headlightActive=0,headlightIntensity=1).items():program[n].value=v
noise.use(1);depth_tex.use(0)
profile('sandstorm')
camera(eye=(4096,500,7000),target=(4096,500,3000),ortho=True,foreground=False)
row_y=500+((np.arange(h)+.5)/h*2-1)*2400

def lighting_delta():
    unlit=render(radianceActive=0)
    lit=render(radianceActive=1)
    assert np.array_equal(lit[...,3],unlit[...,3]),'lighting changed fog opacity'
    return lit[...,:3]-unlit[...,:3]

def set_height(bottom,top,fade):
    height_data[:]=(bottom,top,fade,1);fields[1].write(height_data.tobytes())

for bottom,top,fade in [(0,40,24),(300,420,32),(200,700,100)]:
    set_height(bottom,top,fade);delta=lighting_delta()
    assert delta[(row_y>bottom)&(row_y<top)].sum()>1,'no light at source height'
    assert np.abs(delta[(row_y<bottom-fade)|(row_y>top+fade)]).max()<1e-6,'infinite light column'
# Two distinct source heights next to each other must leave intermediate air dark.
height_data[:,:field_size//2]=(0,40,24,1);height_data[:,field_size//2:] = (300,420,32,1)
radiance_data[:,:field_size//2]=(2,0,0);radiance_data[:,field_size//2:]=(0,0,2)
fields[0].write(radiance_data.tobytes());fields[1].write(height_data.tobytes())
delta=lighting_delta();assert np.abs(delta[(row_y>100)&(row_y<240)]).max()<1e-6,'invented emitter between heights'
assert delta[(row_y>0)&(row_y<40),:w//2,0].sum()>0
assert delta[(row_y>300)&(row_y<420),w//2:,2].sum()>0
set_height(0,1000,24)
occupancy_data[:]=1;fields[2].write(occupancy_data.tobytes())
assert np.abs(lighting_delta()).max()<1e-6,'light leaked into occupied columns'
occupancy_data[:]=0;fields[2].write(occupancy_data.tobytes())
height_data[...,3]=0;fields[1].write(height_data.tobytes())
assert np.abs(lighting_delta()).max()<1e-6,'missing metadata fell back to a light column'
set_height(0,40,24);radiance_data[:]=0;fields[0].write(radiance_data.tobytes())
assert np.abs(lighting_delta()).max()<1e-6,'removed light left glow'
headlight_data[:]=(1,.9,.7);fields[3].write(headlight_data.tobytes())
program['headlightActive'].value=1
assert lighting_delta().sum()>1,'live headlights absent'
program['headlightIntensity'].value=0
assert np.abs(lighting_delta()).max()<1e-6,'day-disabled headlights still lit fog'
program['headlightActive'].value=0
# Same emitting strip farther behind the fog must be dimmer after extinction.
set_height(0,1000,24)
def strip(z0,z1):
    radiance_data[:]=0;radiance_data[z0:z1,:,:]=1;fields[0].write(radiance_data.tobytes())
    return lighting_delta().sum()
near=strip(36,48);far=strip(8,20)
assert 0<far<near,'foreground fog did not attenuate distant light'
assert render(strength=0).max()==0,'clear air emitted local fog light'
render(strength=1,radianceActive=0)
print('PASS fog light: finite unit/lamp height, no intermediate-height source, occupancy, provider/removal, headlights, extinction')
print('PASS production GLSL + map DDS: all presets, depth conventions, pause, animation,')
print('     orthographic/inside/horizontal cameras, foreground clipping, dust front, night shading')
if '--preview' in sys.argv:
    from PIL import Image,ImageDraw
    sheet=Image.new('RGB',(w*3,h+28));draw=ImageDraw.Draw(sheet)
    for i,(name,background,fog) in enumerate(previews):
        rgb=fog[...,:3]+background*(1-fog[...,3:])
        im=Image.fromarray(np.uint8(np.clip(rgb[::-1],0,1)*255))
        sheet.paste(im,(i*w,28));draw.text((i*w+8,8),name,fill='white')
    sheet.save(sys.argv[sys.argv.index('--preview')+1])

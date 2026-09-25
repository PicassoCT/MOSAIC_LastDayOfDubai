#!/usr/bin/env python3
"""Convert the approved 2:1 panoramas to legacy RGBA DDS cubemaps.

Requires numpy and Pillow. No repainting or texture synthesis is performed.
Faces use DDS/OpenGL order +X,-X,+Y,-Y,+Z,-Z, with the Y convention used
by Recoil's skybox shader (uvFlip = 1,-1,1). Sources remain untouched.
"""
from pathlib import Path
import struct
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'maps' / 'skyboxes'
SIZE = 512


def sample_panorama(pixels, x, y, z):
    height, width = pixels.shape[:2]
    radius = np.sqrt(x*x + y*y + z*z)
    u = (np.arctan2(z, x) / (2*np.pi) + .5) * width - .5
    v = (.5 - np.arcsin(np.clip(y/radius, -1, 1)) / np.pi) * height - .5
    v = np.clip(v, 0, height-1)
    ix, iy = np.floor(u).astype(int), np.floor(v).astype(int)
    fx, fy = (u-ix)[..., None], (v-iy)[..., None]
    a = pixels[iy, ix % width]
    b = pixels[iy, (ix+1) % width]
    c = pixels[np.minimum(iy+1, height-1), ix % width]
    d = pixels[np.minimum(iy+1, height-1), (ix+1) % width]
    return np.rint((a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy).astype('uint8')


def convert(source):
    pixels = np.asarray(Image.open(source).convert('RGBA'), dtype=np.float32)
    assert pixels.shape[1] == 2*pixels.shape[0], source
    axis = (np.arange(SIZE)+.5)*2/SIZE-1
    s, t = np.meshgrid(axis, axis)
    one = np.ones_like(s)
    directions = [(one,-t,-s),(-one,-t,s),(s,one,t),
                  (s,-one,-t),(s,-t,one),(-s,-t,-one)]
    # Header: RGBA8, all six cubemap faces, complete mip chain.
    levels = SIZE.bit_length()
    header = [124, 0x2100F, SIZE, SIZE, SIZE*4, 0, levels] + [0]*11
    header += [32, 0x41, 0, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000]
    header += [0x401008, 0xFE00, 0, 0, 0]
    target = ROOT / (source.stem+'.dds')
    faces = [Image.fromarray(sample_panorama(pixels,x,-y,z)) for x,y,z in directions]
    # nv_dds flips every face vertically and exchanges +Y/-Y on load.
    # Apply the inverse here so the uploaded cube matches the shader convention.
    faces[2], faces[3] = faces[3], faces[2]
    with target.open('wb') as output:
        output.write(b'DDS '+struct.pack('<31I', *header))
        for face in faces:
            face = face.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            for level in range(levels):
                if level:
                    face = face.resize((max(1,SIZE >> level),)*2, Image.Resampling.BOX)
                output.write(face.tobytes())
    print(target.name, target.stat().st_size)


if __name__ == '__main__':
    for source in sorted((ROOT/'sources').glob('*.png')):
        convert(source)

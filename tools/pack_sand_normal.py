"""Condition a generated tangent-space normal into a 2K runtime texture.
This is a vector-data conversion, not a recovery of missing source detail.
"""
from pathlib import Path
import sys
import numpy as np
from PIL import Image

source, destination = map(Path, sys.argv[1:3])
im = Image.open(source).convert('RGB')
# Power-of-two runtime dimensions. Generated input is 1254 square, not native 2K.
im = im.resize((2048, 2048), Image.Resampling.LANCZOS)
n = np.asarray(im, dtype=np.float32) / 127.5 - 1.0
# Positive tangent Z; renormalize the encoded vectors before lighting uses them.
n[..., 2] = np.maximum(n[..., 2], 0.01)
n /= np.linalg.norm(n, axis=2, keepdims=True)
out = np.rint(np.clip(n * 0.5 + 0.5, 0, 1) * 255).astype('uint8')
Image.fromarray(out).save(destination)
print(destination, destination.stat().st_size)

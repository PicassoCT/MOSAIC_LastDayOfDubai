#version 150 compatibility
uniform sampler2D terrainHeightTex;
in vec2 screenUV;
void main() {
    ivec2 size = textureSize(terrainHeightTex, 0);
    int x = clamp(int(screenUV.x*float(size.x-1)), 0, size.x-2);
    float stop = -1.0; // uninterrupted land reaches the northern border
    // Read both edges of each 8-unit terrain column. A wet corner blocks
    // that column conservatively; even a one-cell river must not be skipped.
    for (int z = size.y-1; z >= 0; --z) {
        float h = min(texelFetch(terrainHeightTex, ivec2(x,z), 0).r,
                      texelFetch(terrainHeightTex, ivec2(x+1,z), 0).r);
        if (h <= 0.0) {
            stop = min(1.0, float(z+1)/float(size.y-1));
            break;
        }
    }
    gl_FragColor = vec4(stop, 0.0, 0.0, 1.0);
}

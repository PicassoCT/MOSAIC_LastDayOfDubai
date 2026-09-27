#version 150 compatibility
// Based on Anarchid/jK's Volumetric Clouds (GPL v2 or later).
out vec2 screenUV;
void main() {
    screenUV = gl_MultiTexCoord0.st;
    gl_Position = gl_Vertex;
}

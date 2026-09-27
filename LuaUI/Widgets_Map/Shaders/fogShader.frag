#version 150 compatibility
// Map-owned adaptation of Anarchid/jK's Volumetric Clouds, GPL v2 or later.
// Live uniforms allow weather fades without shader recompilation.
uniform sampler2D depthtex;
uniform sampler3D noise3dtex;
uniform mat4 viewProjectionInv;
uniform int zeroToOne;
uniform vec3 offset;
uniform vec3 sundir;
uniform vec3 suncolor;
uniform vec3 fogColor;
uniform vec3 fogBounds; // bottom, fade altitude, ceiling
uniform float noiseScale;
uniform float extinction;
uniform float opacity;
uniform float strength;
uniform int weatherKind; // 1 dawn fog, 2 city smog, 3 sandstorm
uniform float eventPhase;
uniform vec2 mapSize;
uniform float time;
in vec2 screenUV;

const mat3 octaveRotation = mat3(0.00, 0.80, 0.60, -0.80, 0.36, -0.48, -0.60, -0.48, 0.64)*2.01;

vec3 worldPosition(float depth) {
    float z = zeroToOne != 0 ? depth : depth*2.0-1.0;
    vec4 p = viewProjectionInv*vec4(screenUV*2.0-1.0, z, 1.0);
    return p.xyz/p.w;
}

float cloudNoise(vec3 p) {
    p = (p+offset)*noiseScale;
    p.y += time*0.035;
    float n = texture3D(noise3dtex, fract(p*0.2)).r;
    p = octaveRotation*p;
    n += 0.4*texture3D(noise3dtex, fract(p*0.2+time*0.006)).r;
    p = octaveRotation*p;
    n += 0.2*texture3D(noise3dtex, fract(p*0.2-time*0.009)).r;
    return smoothstep(0.18, 1.1, n);
}

float densityAt(vec3 p) {
    float vertical = smoothstep(fogBounds.x, fogBounds.x+20.0, p.y)
        *(1.0-smoothstep(fogBounds.y, fogBounds.z, p.y));
    vec2 uv = p.xz/mapSize;
    float region = 1.0;
    if (weatherKind == 1) {
        // Northern coast and lower city; fade toward the southern desert.
        region = mix(1.0, 0.28, smoothstep(0.25, 0.8, uv.y));
    } else if (weatherKind == 2) {
        region = smoothstep(-0.08, 0.18, uv.y)*(1.0-smoothstep(0.62, 0.95, uv.y));
        region *= smoothstep(-0.1, 0.1, uv.x)*(1.0-smoothstep(0.9, 1.1, uv.x));
    } else {
        // A broad dust front advances north from the desert before fading out.
        float front = mix(0.95, -0.25, smoothstep(0.0, 0.65, eventPhase));
        region = smoothstep(front-0.2, front+0.12, uv.y);
    }
    return cloudNoise(p)*vertical*region;
}

void main() {
    gl_FragColor = vec4(0.0);
    if (strength <= 0.0 || opacity <= 0.0) return;
    float depth = texture2D(depthtex, screenUV).r;
    // Starting at the near plane also handles orthographic cameras and being in fog.
    vec3 origin = worldPosition(0.0);
    vec3 destination = worldPosition(min(depth, 0.99999));
    vec3 segment = destination-origin;
    float sceneDistance = length(segment);
    if (sceneDistance < 0.001) return;
    vec3 direction = segment/sceneDistance;
    float begin = 0.0;
    float end = min(sceneDistance, 18000.0);
    if (abs(direction.y) < 0.00001) {
        if (origin.y <= fogBounds.x || origin.y >= fogBounds.z) return;
    } else {
        float a = (fogBounds.x-origin.y)/direction.y;
        float b = (fogBounds.z-origin.y)/direction.y;
        begin = max(begin, min(a, b));
        end = min(end, max(a, b));
    }
    if (end <= begin) return;

    const int steps = 24;
    float stepLength = (end-begin)/float(steps);
    float opticalDepth = 0.0;
    float lightSum = 0.0;
    float densitySum = 0.0;
    vec3 lightDirection = sundir/max(length(sundir), 0.001);
    for (int i = 0; i < steps; ++i) {
        vec3 p = origin+direction*(begin+(float(i)+0.5)*stepLength);
        float density = densityAt(p);
        opticalDepth += density*stepLength*extinction*strength;
        // Neighbour density gives softly shaded lobes, with no game lighting dependency.
        float visibility = clamp(0.35+(density-densityAt(p+lightDirection*65.0))*2.5, 0.12, 1.0);
        lightSum += visibility*density;
        densitySum += density;
    }
    float alpha = min(opacity, 1.0-exp(-opticalDepth));
    float sunlight = smoothstep(-0.12, 0.18, lightDirection.y);
    vec3 ambient = mix(vec3(0.10, 0.13, 0.20), vec3(0.72), sunlight);
    float scattering = lightSum/max(densitySum, 0.001);
    float forwardGlow = pow(max(dot(direction, lightDirection), 0.0), 12.0)*0.22;
    vec3 color = fogColor*(ambient+max(suncolor, vec3(0.0))*sunlight*(scattering*0.38+forwardGlow));
    gl_FragColor = vec4(color*alpha, alpha);
}

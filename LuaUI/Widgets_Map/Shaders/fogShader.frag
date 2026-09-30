#version 150 compatibility
// Map-owned adaptation of Anarchid/jK's Volumetric Clouds, GPL v2 or later.
// Live uniforms allow weather fades without shader recompilation.
uniform sampler2D depthtex;
uniform sampler3D noise3dtex;
uniform sampler2D terrainHeightTex; // engine-owned $heightmap, world-space heights
uniform vec2 groundWaveBounds; // conservative terrain min/max + wave height
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
uniform sampler2D radianceTex;
uniform sampler2D heightEnvelopeTex;
uniform sampler2D occupancyTex;
uniform sampler2D headlightTex;
uniform int radianceActive;
uniform int headlightActive;
uniform float radianceStrength;
uniform float headlightIntensity;
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

// Southern edge is +Z. Positive time in the sampled Z coordinate moves
// features toward -Z (north), independently of wind or camera orientation.
float sandWaveDensity(vec3 p) {
    vec2 uv = p.xz/mapSize;
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
    vec2 size = vec2(textureSize(terrainHeightTex, 0));
    vec2 heightUV = (uv*(size-1.0)+0.5)/size;
    float ground = texture2D(terrainHeightTex, heightUV).r;
    float above = p.y-ground;
    if (above <= 0.0 || above >= 64.0 || ground <= 0.0) return 0.0;
    vec3 drift = vec3(p.x/850.0, above/180.0, (p.z+time*140.0)/640.0);
    float breakup = texture3D(noise3dtex, fract(drift*0.37)).r;
    float warp = texture3D(noise3dtex, fract(vec3(p.x/2400.0, 0.31, (p.z+time*140.0)/1900.0))).r;
    float crest = 0.5+0.5*cos(6.2831853*(drift.z+warp*0.8));
    float bands = smoothstep(0.48, 0.94, crest)*smoothstep(0.12, 0.7, breakup);
    float height = mix(22.0, 64.0, breakup);
    float vertical = smoothstep(0.0, 4.0, above)*(1.0-smoothstep(8.0, height, above));
    float front = mix(1.02, -0.15, smoothstep(0.0, 0.65, eventPhase));
    float reach = smoothstep(front-0.04, front+0.06, uv.y);
    float edges = smoothstep(0.0, 0.025, uv.x)*(1.0-smoothstep(0.975, 1.0, uv.x));
    // Strongest at the desert entrance, thinning toward the coast; never over water.
    return bands*vertical*reach*edges*smoothstep(0.0, 8.0, ground)*mix(0.35, 1.0, uv.y)*3.5;
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

vec3 localFogLight(vec3 p) {
    if(radianceActive == 0) return vec3(0.0);
    vec2 uv = p.xz/mapSize;
    if(any(lessThan(uv,vec2(0.0))) || any(greaterThanEqual(uv,vec2(1.0)))) return vec3(0.0);
    // NEAREST-filtered bounds belong to one actual source unit/lamp. Never blend
    // heights from different buildings into a fictional emitter between floors.
    vec4 envelope = texture2D(heightEnvelopeTex,uv);
    if(envelope.a <= 0.0 || envelope.b <= 0.0) return vec3(0.0);
    float outside = max(max(envelope.r-p.y,p.y-envelope.g),0.0);
    if(outside >= envelope.b) return vec3(0.0);
    float vertical = 1.0-smoothstep(0.0,envelope.b,outside);
    // Reuse the cascade's conservative horizontal shadowing, with no new shadow rays.
    if(texture2D(occupancyTex,uv).r > 0.5) return vec3(0.0);
    vec3 light = max(texture2D(radianceTex,uv).rgb,vec3(0.0));
    if(headlightActive != 0)
        light = max(light,max(texture2D(headlightTex,uv).rgb,vec3(0.0))*headlightIntensity);
    return (vec3(1.0)-exp(-light*radianceStrength))*vertical*envelope.a;
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

    // Concentrate samples around the terrain so shallow waves cannot fall
    // between the tall storm's coarse samples. All intervals remain ordered
    // front-to-back for the existing extinction and local-light integration.
    float groundBegin = begin;
    float groundEnd = begin;
    if (weatherKind == 3) {
        if (abs(direction.y) < 0.00001) {
            if (origin.y >= groundWaveBounds.x && origin.y <= groundWaveBounds.y)
                groundEnd = end;
        } else {
            float a = (groundWaveBounds.x-origin.y)/direction.y;
            float b = (groundWaveBounds.y-origin.y)/direction.y;
            groundBegin = clamp(min(a, b), begin, end);
            groundEnd = clamp(max(a, b), begin, end);
        }
    }
    bool groundSamples = weatherKind == 3 && groundEnd > groundBegin;
    float opticalDepth = 0.0;
    float lightSum = 0.0;
    float densitySum = 0.0;
    vec3 scatteredLight = vec3(0.0);
    vec3 lightDirection = sundir/max(length(sundir), 0.001);
    float fogStep = (end-begin)/24.0;
    float waveStep = (groundEnd-groundBegin)/24.0;
    int fogIndex = 0;
    int waveIndex = 0;
    // Merge two independent quadratures by distance. Keep the original fog
    // samples stable when the ground interval becomes tiny or leaves the view.
    for (int i = 0; i < 48; ++i) {
        bool hasFog = fogIndex < 24;
        bool hasWave = groundSamples && waveIndex < 24;
        if (!hasFog && !hasWave) break;
        float fogDistance = begin+(float(fogIndex)+0.5)*fogStep;
        float waveDistance = groundBegin+(float(waveIndex)+0.5)*waveStep;
        bool wave = hasWave && (!hasFog || waveDistance < fogDistance);
        float stepLength = wave ? waveStep : fogStep;
        vec3 p = origin+direction*(wave ? waveDistance : fogDistance);
        if (wave) ++waveIndex; else ++fogIndex;
        float density = wave ? sandWaveDensity(p) : densityAt(p);
        float stepDepth = density*stepLength*extinction*strength;
        // Front-to-back transmittance: a distant glow cannot shine through a
        // thick foreground bank. Height is checked at EVERY density sample.
        if(density > 0.0001)
            scatteredLight += localFogLight(p)*exp(-opticalDepth)*(1.0-exp(-stepDepth));
        opticalDepth += stepDepth;
        // Neighbour density gives softly shaded lobes, with no game lighting dependency.
        float neighbour = wave ? sandWaveDensity(p+lightDirection*16.0) : densityAt(p+lightDirection*65.0);
        float visibility = clamp(0.35+(density-neighbour)*2.5, 0.12, 1.0);
        lightSum += visibility*density*stepLength;
        densitySum += density*stepLength;
    }
    float physicalAlpha = 1.0-exp(-opticalDepth);
    float alpha = min(opacity, physicalAlpha);
    float sunlight = smoothstep(-0.12, 0.18, lightDirection.y);
    vec3 ambient = mix(vec3(0.10, 0.13, 0.20), vec3(0.72), sunlight);
    float scattering = lightSum/max(densitySum, 0.001);
    float forwardGlow = pow(max(dot(direction, lightDirection), 0.0), 12.0)*0.22;
    vec3 color = fogColor*(ambient+max(suncolor, vec3(0.0))*sunlight*(scattering*0.38+forwardGlow));
    vec3 scatteringTint = mix(vec3(1.0),fogColor,0.35);
    vec3 localScattering = scatteredLight*scatteringTint*0.7*(alpha/max(physicalAlpha,0.00001));
    gl_FragColor = vec4(color*alpha+localScattering, alpha);
}

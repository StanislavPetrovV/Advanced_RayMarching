#version 430 core
#include hg_sdf.glsl
layout (location = 0) out vec4 fragColor;

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform float u_scroll;
uniform sampler2D u_texture1;
uniform sampler2D u_texture2;
uniform sampler2D u_texture3;
uniform sampler2D u_texture4;
uniform sampler2D u_texture5;
uniform sampler2D u_texture6;
uniform sampler2D u_texture7;

const float FOV = 1.0;
const int MAX_STEPS = 128;
const float MAX_DIST = 500;
const float EPSILON = 0.01;

// choose antialising - 1 2 3 4
const int AA = 1;  

float cubeSize = 6.0;

float cubeScale = 1.0 / cubeSize;
float roofScale = 0.15;
float pedestalScale = 0.3;
float floorScale = 0.15;
float sphereScale = 0.2;
float wallScale = 0.12;

float roofBumpFactor = 0.31;
float sphereBumpFactor = 0.21;
float wallBumpFactor = 0.06;


void translateSphere(inout vec3 p) {
    p.y -= 4.4;
}

void rotateSphere(inout vec3 p) {
    pR(p.xz, 0.3 * u_time);
}

void translateCube(inout vec3 p) {
    p.y -= 2.5;
    p.xz += 1.5;
}

void rotateCube(inout vec3 p) {
    pR(p.yz, PI / 4);
    pR(p.xz, u_time);
}


vec3 triPlanar(sampler2D tex, vec3 p, vec3 normal) {
    normal = abs(normal);
    normal = pow(normal, vec3(5.0));
    normal /= normal.x + normal.y + normal.z;
    return (texture(tex, p.xy * 0.5 + 0.5) * normal.z +
            texture(tex, p.xz * 0.5 + 0.5) * normal.y +
            texture(tex, p.yz * 0.5 + 0.5) * normal.x).rgb;
}


float bumpMapping(sampler2D tex, vec3 p, vec3 n, float dist, float factor, float scale) {
    float bump = 0.0;
    if (dist < 0.1) {
        vec3 normal = normalize(n);
        bump += factor * triPlanar(tex, (p * scale), normal).r;
    }
    return bump;
}


vec2 fOpUnionID(vec2 res1, vec2 res2) {
    return (res1.x < res2.x) ? res1 : res2;
}

vec2 fOpDifferenceID(vec2 res1, vec2 res2) {
    return (res1.x > -res2.x) ? res1 : vec2(-res2.x, res2.y);
}

vec2 fOpDifferenceColumnsID(vec2 res1, vec2 res2, float r, float n) {
    float dist = fOpDifferenceColumns(res1.x, res2.x, r, n);
    return (res1.x > -res2.x) ? vec2(dist, res1.y) : vec2(dist, res2.y);
}

vec2 fOpUnionStairsID(vec2 res1, vec2 res2, float r, float n) {
    float dist = fOpUnionStairs(res1.x, res2.x, r, n);
    return (res1.x < res2.x) ? vec2(dist, res1.y) : vec2(dist, res2.y);
}

vec2 fOpUnionChamferID(vec2 res1, vec2 res2, float r) {
    float dist = fOpUnionChamfer(res1.x, res2.x, r);
    return (res1.x < res2.x) ? vec2(dist, res1.y) : vec2(dist, res2.y);
}


/*-- map, getMaterial functions --*/
#include map.glsl
#include material.glsl
/*--------------------------------*/


vec2 rayMarch(vec3 ro, vec3 rd) {
    vec2 hit, object;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + object.x * rd;
        hit = map(p);
        object.x += hit.x;
        object.y = hit.y;
        if (abs(hit.x) < EPSILON || object.x > MAX_DIST) break;
    }
    return object;
}


vec3 getNormal(vec3 p) {
    vec2 e = vec2(EPSILON, 0.0);
    vec3 n = vec3(map(p).x) - vec3(map(p - e.xyy).x, map(p - e.yxy).x, map(p - e.yyx).x);
    return normalize(n);
}


float getSoftShadow(vec3 p, vec3 lightPos) {
    float res = 1.0;
    float dist = 0.01;
    float lightSize = 0.03;
    for (int i = 0; i < MAX_STEPS; i++) {
        float hit = map(p + lightPos * dist).x;
        res = min(res, hit / (dist * lightSize));
        dist += hit;
        if (hit < 0.0001 || dist > 60.0) break;
    }
    return clamp(res, 0.0, 1.0);
}


float getAmbientOcclusion(vec3 p, vec3 normal) {
    float occ = 0.0;
    float weight = 1.0;
    for (int i = 0; i < 8; i++) {
        float len = 0.01 + 0.02 * float(i * i);
        float dist = map(p + normal * len).x;
        occ += (len - dist) * weight;
        weight *= 0.85;
    }
    return 1.0 - clamp(0.6 * occ, 0.0, 1.0);
}


vec3 getLight(vec3 p, vec3 rd, float id) {
    vec3 lightPos = vec3(20.0, 55.0, -25.0);
    vec3 L = normalize(lightPos - p);
    vec3 N = getNormal(p);
    vec3 V = -rd;
    vec3 R = reflect(-L, N);

    vec3 color = getMaterial(p, id, N);

    vec3 specColor = vec3(0.6, 0.5, 0.4);
    vec3 specular = 1.3 * specColor * pow(clamp(dot(R, V), 0.0, 1.0), 10.0);
    vec3 diffuse = 0.9 * color * clamp(dot(L, N), 0.0, 1.0);
    vec3 ambient = 0.05 * color;
    vec3 fresnel = 0.15 * color * pow(1.0 + dot(rd, N), 3.0);

    // shadows
    float shadow = getSoftShadow(p + N * 0.02, normalize(lightPos));
    // occ
    float occ = getAmbientOcclusion(p, N);
    // back
    vec3 back = 0.05 * color * clamp(dot(N, -L), 0.0, 1.0);

    return  (back + ambient + fresnel) * occ + (specular * occ + diffuse) * shadow;
//    return back;
}


mat3 getCam(vec3 ro, vec3 lookAt) {
    vec3 camF = normalize(vec3(lookAt - ro));
    vec3 camR = normalize(cross(vec3(0, 1, 0), camF));
    vec3 camU = cross(camF, camR);
    return mat3(camR, camU, camF);
}


void mouseControl(inout vec3 ro) {
    vec2 m = u_mouse / u_resolution;
    pR(ro.yz, m.y * PI * 0.39 - 0.39);
    pR(ro.xz, m.x * TAU);
}


vec3 render(vec2 uv) {
    vec3 col = vec3(0);
    vec3 background = vec3(0.5, 0.8, 0.9);

    vec3 ro = vec3(36.0, 19.0, -36.0) / u_scroll;
    mouseControl(ro);

    vec3 lookAt = vec3(0, 1, 0);
    vec3 rd = getCam(ro, lookAt) * normalize(vec3(uv, FOV));

    vec2 object = rayMarch(ro, rd);

    if (object.x < MAX_DIST) {
        vec3 p = ro + object.x * rd;
        col += getLight(p, rd, object.y);
        // fog
        col = mix(col, background, 1.0 - exp(-1e-7 * object.x * object.x * object.x));
    } else {
        col += background - max(0.9 * rd.y, 0.0);
    }
    return col;
}


vec2 getUV(vec2 offset) {
    return (2.0 * (gl_FragCoord.xy + offset) - u_resolution.xy) / u_resolution.y;
}


vec3 renderAAx1() {
    return render(getUV(vec2(0)));
}


vec3 renderAAx2() {
    float bxy = int(gl_FragCoord.x + gl_FragCoord.y) & 1;
    float nbxy = 1. - bxy;
    vec3 colAA = (render(getUV(vec2(0.33 * nbxy, 0.))) + render(getUV(vec2(0.33 * bxy, 0.66))));
    return colAA / 2.0;
}


vec3 renderAAx3() {
    float bxy = int(gl_FragCoord.x + gl_FragCoord.y) & 1;
    float nbxy = 1. - bxy;
    vec3 colAA = (render(getUV(vec2(0.66 * nbxy, 0.))) +
                  render(getUV(vec2(0.66 * bxy, 0.66))) +
                  render(getUV(vec2(0.33, 0.33))));
    return colAA / 3.0;
}


vec3 renderAAx4() {
    vec4 e = vec4(0.125, -0.125, 0.375, -0.375);
    vec3 colAA = render(getUV(e.xz)) + render(getUV(e.yw)) + render(getUV(e.wx)) + render(getUV(e.zy));
    return colAA /= 4.0;
}


void main() {
    vec3 color = (AA == 1) ? renderAAx1() : (AA == 2) ? renderAAx2() : (AA == 3) ? renderAAx3(): renderAAx4();
    // gamma correction
    color = pow(color, vec3(0.4545));
    fragColor = vec4(color, 1.0);
}
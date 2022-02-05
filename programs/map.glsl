vec2 getPedestal(vec3 p) {
    float ID = 9.0;
    float resDist;
    // box 1
    p.y += 13.8;
    float box1 = fBoxCheap(p, vec3(8, 0.4, 8));
    // box 2
    p.y -= 6.4;
    float box2 = fBoxCheap(p, vec3(7, 6, 7));
    // box 3
    pMirrorOctant(p.zx, vec2(7.5, 7.5));
    float box3 = fBoxCheap(p, vec3(5, 4, 1));
    // res
    resDist = box1;
    resDist = min(resDist, box2);
    resDist = fOpDifferenceColumns(resDist, box3, 1.9, 10.0);
    return vec2(resDist, ID);
}

vec2 map(vec3 p) {
    vec3 tmp, op = p;
    // plane
    float planeDist = fPlane(p, vec3(0, 1, 0), 14.0);
    float planeID = 6.0;
    vec2 plane = vec2(planeDist, planeID);

    // cube
//    vec3 pb = p;
//    translateCube(pb);
//    rotateCube(pb);
//    float cubeDist = fBoxCheap(pb, vec3(cubeSize));
//    float cubeID = 5.0;
//    vec2 cube = vec2(cubeDist, cubeID);

    // pedestal
    vec2 pedestal = getPedestal(p);

    // sphere
    vec3 ps = p;
    translateSphere(ps);
    rotateSphere(ps);
    float sphereDist = fSphere(ps, 6.0);
    sphereDist += bumpMapping(u_texture6, ps, ps + sphereBumpFactor,
                              sphereDist, sphereBumpFactor, sphereScale);
    sphereDist += sphereBumpFactor;
    float sphereID = 10.0;
    vec2 sphere = vec2(sphereDist, sphereID);

    // manipulation operators
    pMirrorOctant(p.xz, vec2(50, 50));
    p.x = -abs(p.x) + 20;
    pMod1(p.z, 15);

    // roof
    vec3 pr = p;
    pr.y -= 15.7;
    pR(pr.xy, 0.6);
    pr.x -= 18.0;
    float roofDist = fBox2Cheap(pr.xy, vec2(20, 0.5));
    roofDist -= bumpMapping(u_texture7, p, p - roofBumpFactor, roofDist, roofBumpFactor, roofScale);
    roofDist += roofBumpFactor;
    float roofID = 8.0;
    vec2 roof = vec2(roofDist, roofID);

    // box
    float boxDist = fBoxCheap(p, vec3(3,9,4));
    float boxID = 7.0;
    vec2 box = vec2(boxDist, boxID);

    // cylinder
    vec3 pc = p;
    pc.y -= 9.0;
    float cylinderDist = fCylinder(pc.yxz, 4, 3);
    float cylinderID = 7.0;
    vec2 cylinder = vec2(cylinderDist, cylinderID);

    // wall
    float wallDist = fBox2Cheap(p.xy, vec2(1, 15));
    wallDist -= bumpMapping(u_texture3, op, op + wallBumpFactor, wallDist, wallBumpFactor, wallScale);
    wallDist += wallBumpFactor;
    float wallID = 7.0;
    vec2 wall = vec2(wallDist, wallID);

    // result
    vec2 res;
    res = fOpUnionID(box, cylinder);
    res = fOpDifferenceColumnsID(wall, res, 0.6, 3.0);
    res = fOpUnionChamferID(res, roof, 0.6);
    res = fOpUnionStairsID(res, plane, 4.0, 5.0);
    res = fOpUnionID(res, sphere);
    res = fOpUnionID(res, pedestal);
//    res = fOpUnionID(res, cube);
    res = res;
    return res;
}
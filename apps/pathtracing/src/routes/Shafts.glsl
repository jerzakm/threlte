precision highp float;
precision highp int;
precision highp sampler2D;

#include <pathtracing_uniforms_and_defines>

uniform mat4 uTorusInvMatrix;
uniform float uSamplesPerFrame;
uniform float uPreviousFrameBlendWeight;

uniform vec3 dBoxMinCorners[16];
uniform vec3 dBoxMaxCorners[16];
uniform vec3 dBoxMaxEmissions[16];
uniform vec3 dBoxColors[16];
uniform mat4 dBoxInvMatrices[16];
uniform int dBoxTypes[16];

uniform sampler2D tHDRTexture;
uniform vec3 uSunDirectionVector;
uniform float uHDRI_Exposure;

#define N_LIGHTS 3.0
#define N_SPHERES 6
#define N_PLANES 1
#define N_DISKS 1
#define N_TRIANGLES 1
#define N_QUADS 5
#define N_BOXES 2
#define N_ELLIPSOIDS 1
#define N_PARABOLOIDS 1
#define N_OPENCYLINDERS 1
#define N_CAPPEDCYLINDERS 1
#define N_CONES 1
#define N_CAPSULES 1
#define N_TORII 1

//-----------------------------------------------------------------------

vec3 rayOrigin, rayDirection;
// recorded intersection data:
vec3 hitNormal, hitEmission, hitColor;
vec2 hitUV;
float hitObjectID;
int hitType = -100;

struct Sphere {
  float radius;
  vec3 position;
  vec3 emission;
  vec3 color;
  int type;
};
struct Ellipsoid {
  vec3 radii;
  vec3 position;
  vec3 emission;
  vec3 color;
  int type;
};
struct Paraboloid {
  float rad;
  float height;
  vec3 pos;
  vec3 emission;
  vec3 color;
  int type;
};
struct OpenCylinder {
  float radius;
  float height;
  vec3 position;
  vec3 emission;
  vec3 color;
  int type;
};
struct CappedCylinder {
  float radius;
  vec3 cap1pos;
  vec3 cap2pos;
  vec3 emission;
  vec3 color;
  int type;
};
struct Cone {
  vec3 pos0;
  float radius0;
  vec3 pos1;
  float radius1;
  vec3 emission;
  vec3 color;
  int type;
};
struct Capsule {
  vec3 pos0;
  float radius0;
  vec3 pos1;
  float radius1;
  vec3 emission;
  vec3 color;
  int type;
};
struct UnitTorus {
  float parameterK;
  vec3 emission;
  vec3 color;
  int type;
};
struct Box {
  vec3 minCorner;
  vec3 maxCorner;
  vec3 emission;
  vec3 color;
  int type;
};

struct Quad {
  vec3 normal;
  vec3 v0;
  vec3 v1;
  vec3 v2;
  vec3 v3;
  vec3 emission;
  vec3 color;
  int type;
};

Sphere spheres[N_SPHERES];
Ellipsoid ellipsoids[N_ELLIPSOIDS];
Paraboloid paraboloids[N_PARABOLOIDS];
OpenCylinder openCylinders[N_OPENCYLINDERS];
CappedCylinder cappedCylinders[N_CAPPEDCYLINDERS];
Cone cones[N_CONES];
Capsule capsules[N_CAPSULES];
UnitTorus torii[N_TORII];
Box boxes[N_BOXES];
Quad quads[N_QUADS];

#include <pathtracing_random_functions>

#include <pathtracing_calc_fresnel_reflectance>

#include <pathtracing_sphere_intersect>

#include <pathtracing_unit_bounding_sphere_intersect>

#include <pathtracing_ellipsoid_intersect>

#include <pathtracing_opencylinder_intersect>

#include <pathtracing_cappedcylinder_intersect>

#include <pathtracing_cone_intersect>

#include <pathtracing_capsule_intersect>

#include <pathtracing_paraboloid_intersect>

#include <pathtracing_unit_torus_intersect>

#include <pathtracing_box_intersect>

#include <pathtracing_quad_intersect>

#include <pathtracing_sample_sphere_light>

vec3 randPointOnLight; // global variable that can be used across multiple functions

vec3 sampleQuadLight(vec3 x, vec3 nl, Quad light, out float weight) {
	// vec3 randPointOnLight is already chosen on each bounces loop iteration below in the CalculateRadiance() function 

  vec3 dirToLight = randPointOnLight - x;
  float r2 = distance(light.v0, light.v1) * distance(light.v0, light.v3);
  float d2 = dot(dirToLight, dirToLight);
  float cos_a_max = sqrt(1.0 - clamp(r2 / d2, 0.0, 1.0));
  dirToLight = normalize(dirToLight);
  float dotNlRayDir = max(0.0, dot(nl, dirToLight));
  weight = 2.0 * (1.0 - cos_a_max) * max(0.0, -dot(dirToLight, light.normal)) * dotNlRayDir;
  weight = clamp(weight, 0.0, 1.0);
  return dirToLight;
}
//----------------------------------------------------------------------------------------------------------------------------------------
float BoxMissingSidesIntersect(vec3 minCorner, vec3 maxCorner, vec3 rayOrigin, vec3 rayDirection, out vec3 normal, out int isRayExiting)
//----------------------------------------------------------------------------------------------------------------------------------------
{
  vec3 invDir = 1.0 / rayDirection;
  vec3 near = (minCorner - rayOrigin) * invDir;
  vec3 far = (maxCorner - rayOrigin) * invDir;

  vec3 tmin = min(near, far);
  vec3 tmax = max(near, far);

  float t0 = max(max(tmin.x, tmin.y), tmin.z);
  float t1 = min(min(tmax.x, tmax.y), tmax.z);

  if(t0 > t1)
    return INFINITY;

  vec3 ip;
  float result = INFINITY;
  if(t0 > 0.0) // if we are outside the box
  {
    normal = -sign(rayDirection) * step(tmin.yzx, tmin) * step(tmin.zxy, tmin);
    isRayExiting = FALSE;
    ip = rayOrigin + rayDirection * t0;
    if(normal == vec3(1, 0, 0) && abs(ip.y) < 2.0 && abs(ip.z) < 2.0)
      t0 = INFINITY;
    if(normal == vec3(0, 1, 0) || normal == vec3(0, 0, 1))
      t0 = INFINITY;
    result = t0;
  }
  if((t0 < 0.0 || t0 == INFINITY) && t1 > 0.0) // if we are inside the box
  {
    normal = -sign(rayDirection) * step(tmax, tmax.yzx) * step(tmax, tmax.zxy);
    isRayExiting = TRUE;
    ip = rayOrigin + rayDirection * t1;
    if(normal == vec3(-1, 0, 0) && abs(ip.y) < 2.0 && abs(ip.z) < 2.0)
      t1 = INFINITY;
    if(normal == vec3(0, -1, 0) || normal == vec3(0, 0, -1))
      t1 = INFINITY;
    result = t1;
  }
  return result;
}

vec3 Get_HDR_Color(vec3 rDirection) {
  vec2 sampleUV;
	//sampleUV.y = asin(clamp(rDirection.y, -1.0, 1.0)) * ONE_OVER_PI + 0.5;
	///sampleUV.x = (1.0 + atan(rDirection.x, -rDirection.z) * ONE_OVER_PI) * 0.5;
  sampleUV.x = atan(rDirection.x, -rDirection.z) * ONE_OVER_TWO_PI + 0.5;
  sampleUV.y = acos(rDirection.y) * ONE_OVER_PI;
  vec3 texColor = texture(tHDRTexture, sampleUV).rgb;

	// texColor = texData.a > 0.57 ? vec3(100) : vec3(0);
	// return texColor;
  return texColor * uHDRI_Exposure;
}
//------------------------------------------------------------------------------------------------------------------------------------------------------------
float SceneIntersect(vec3 rOrigin, vec3 rDirection, out vec3 hitNormal, out vec3 hitEmission, out vec3 hitColor, out float hitObjectID, out int hitType)
//------------------------------------------------------------------------------------------------------------------------------------------------------------
{
  vec3 n;
  float d;
  float t = INFINITY;
  int objectCount = 0;
  int isRayExiting = FALSE;

  hitObjectID = -INFINITY;

// NOTE: all intersect functions must use rOrigin/rDirection as parameters instead of the usual 
//   global rayOrigin/rayDirection!  This is because rOrigin/rDirection might represent a particle shadow ray

  d = BoxMissingSidesIntersect(boxes[0].minCorner, boxes[0].maxCorner, rOrigin, rDirection, n, isRayExiting);
  if(d < t) {
    t = d;
    hitNormal = n;
    hitEmission = boxes[0].emission;
    hitColor = vec3(1);
    hitType = DIFF;

    if(isRayExiting == TRUE && n == vec3(1, 0, 0)) // left wall
    {
      hitColor = vec3(0.7, 0.05, 0.05);
    } else if(isRayExiting == TRUE && n == vec3(-1, 0, 0)) // right wall
    {
      hitColor = vec3(0.05, 0.05, 0.7);
    } else if(isRayExiting == FALSE && n == vec3(-1, 0, 0)) // left wall
    {
      hitColor = vec3(0.7, 0.05, 0.05);
    } else if(isRayExiting == FALSE && n == vec3(1, 0, 0)) // right wall
    {
      hitColor = vec3(0.05, 0.05, 0.7);
    }

    hitObjectID = float(objectCount);
  }
  objectCount++;

  for(int i = 0; i < N_SPHERES; i++) {
    d = SphereIntersect(spheres[i].radius, spheres[i].position, rOrigin, rDirection);
    if(d < t) {
      t = d;
      hitNormal = (rOrigin + rDirection * t) - spheres[i].position;
      hitEmission = spheres[i].emission;
      hitColor = spheres[i].color;
      hitType = spheres[i].type;
      hitObjectID = float(objectCount);
    }
    objectCount++;
  }

  for(int i = 0; i < N_QUADS; i++) {
    d = QuadIntersect(quads[i].v0, quads[i].v1, quads[i].v2, quads[i].v3, rOrigin, rDirection, TRUE);
    if(d < t) {
      t = d;
      hitNormal = quads[i].normal;
      hitEmission = quads[i].emission;
      hitColor = quads[i].color;
      hitType = quads[i].type;
      hitObjectID = float(objectCount);
    }
    objectCount++;
  }

  for(int i = 0; i < 16; i++) {
    if(dBoxTypes[i] < 0)
      break;

    if(dBoxTypes[i] > 0) {
      rOrigin = vec3(dBoxInvMatrices[i] * vec4(rayOrigin, 1.0));
      rDirection = vec3(dBoxInvMatrices[i] * vec4(rayDirection, 0.0));
      d = BoxIntersect(dBoxMinCorners[i], dBoxMaxCorners[i], rOrigin, rDirection, n, isRayExiting);
      if(d < t) {
        t = d;
        // hitNormal = n;
        hitNormal = transpose(mat3(dBoxInvMatrices[i])) * n;
        hitEmission = vec3(0.5);
        hitColor = dBoxColors[i];
        hitType = dBoxTypes[i];
        // finalIsRayExiting = isRayExiting;
        hitObjectID = float(objectCount);
      }
      objectCount++;
    }
  }

  return t;
} // end float SceneIntersect( vec3 rOrigin, vec3 rDirection, out vec3 hitNormal, out vec3 hitEmission, out vec3 hitColor, out float hitObjectID, out int hitType )

/* Credit: Some of the equi-angular sampling code is borrowed from https://www.shadertoy.com/view/Xdf3zB posted by user 'sjb' ,
// who in turn got it from the paper 'Importance Sampling Techniques for Path Tracing in Participating Media' ,
which can be viewed at: https://docs.google.com/viewer?url=https%3A%2F%2Fwww.solidangle.com%2Fresearch%2Fegsr2012_volume.pdf */
void sampleEquiAngular(float u, float maxDistance, vec3 rOrigin, vec3 rDirection, vec3 lightPos, out float dist, out float pdf) {
	// get coord of closest point to light along (infinite) ray
  float delta = dot(lightPos - rOrigin, rDirection);

	// get distance this point is from light
  float D = distance(rOrigin + delta * rDirection, lightPos);

	// get angle of endpoints
  float thetaA = atan(0.0 - delta, D);
  float thetaB = atan(maxDistance - delta, D);

	// take sample
  float t = D * tan(mix(thetaA, thetaB, u));
  dist = delta + t;
  pdf = D / ((thetaB - thetaA) * (D * D + t * t));
}

#define FOG_COLOR vec3(0.05, 0.05, 0.4) // color of the fog / participating medium
#define FOG_DENSITY 0.001 // this is dependent on the particular scene size dimensions

//-----------------------------------------------------------------------------------------------------------------------------
vec3 CalculateRadiance(out vec3 objectNormal, out vec3 objectColor, out float objectID, out float pixelSharpness)
//-----------------------------------------------------------------------------------------------------------------------------
{
  Quad chosenLight;

  vec3 cameraRayOrigin = rayOrigin;
  vec3 cameraRayDirection = rayDirection;
  vec3 vRayOrigin, vRayDirection;

	// recorded intersection data (from eye):
  vec3 eHitNormal, eHitEmission, eHitColor;
  float eHitObjectID;
  int eHitType = -100; // note: make sure to initialize this to a nonsense type id number!
	// recorded intersection data (from volumetric particle):
  vec3 vHitNormal, vHitEmission, vHitColor;
  float vHitObjectID;
  int vHitType = -100; // note: make sure to initialize this to a nonsense type id number!

  vec3 accumCol = vec3(0.0);
  vec3 mask = vec3(1.0);
  vec3 dirToLight;
  vec3 lightVec;
  vec3 particlePos;
  vec3 tdir;
  vec3 x, n, nl;

  float nc, nt, ratioIoR, Re, Tr;
  float P, RP, TP;
  float weight;
  float t, vt, camt;
  float xx;
  float pdf;
  float d;
  float geomTerm;
  float trans;

  int diffuseCount = 0;
  int previousIntersecType = -100;

  int bounceIsSpecular = TRUE;
  int sampleLight = FALSE;

	// depth of 4 is required for higher quality glass refraction
  for(int bounces = 0; bounces < 4; bounces++) {
    chosenLight = quads[0];
    randPointOnLight.x = chosenLight.v0.x;
    randPointOnLight.y = mix(chosenLight.v0.y, chosenLight.v2.y, clamp(rng(), 0.1, 0.9));
    randPointOnLight.z = mix(chosenLight.v0.z, chosenLight.v2.z, clamp(rng(), 0.1, 0.9));

    float u = rng();

    t = SceneIntersect(rayOrigin, rayDirection, eHitNormal, eHitEmission, eHitColor, eHitObjectID, eHitType);

		// on first loop iteration, save intersection distance along camera ray (t) into camt variable for use below
    if(bounces == 0) {
      camt = t;
    }

		// sample along intial ray from camera into the scene
    sampleEquiAngular(u, camt, cameraRayOrigin, cameraRayDirection, randPointOnLight, xx, pdf);

		// create a particle along cameraRay and cast a shadow ray towards light (similar to Direct Lighting)
    particlePos = cameraRayOrigin + xx * cameraRayDirection;
    lightVec = randPointOnLight - particlePos;
    d = length(lightVec);

    vRayOrigin = particlePos;
    vRayDirection = normalize(lightVec);

    vt = SceneIntersect(vRayOrigin, vRayDirection, vHitNormal, vHitEmission, vHitColor, vHitObjectID, vHitType);

		// if the particle can see the light source, apply volumetric lighting calculation
    if(vHitType == LIGHT) {
      trans = exp(-((d + xx) * FOG_DENSITY));
      geomTerm = 1.0 / (d * d);

      accumCol += FOG_COLOR * vHitEmission * geomTerm * trans / pdf;
    }
		// otherwise the particle will remain in shadow - this is what produces the shafts of light vs. the volume shadows

		// useful data 
    n = normalize(eHitNormal);
    nl = dot(n, rayDirection) < 0.0 ? n : -n;
    x = rayOrigin + rayDirection * t;

    if(bounces == 0) {
			//objectNormal = nl;
      objectColor = eHitColor;
      objectID = eHitObjectID;
    }
    if(diffuseCount == 0) // handles reflections of light sources
    {
      objectNormal = nl;
    }

		// now do the normal path tracing routine with the camera ray
    if(eHitType == LIGHT) {
      if(bounceIsSpecular == TRUE || sampleLight == TRUE) {
        trans = exp(-((d + camt) * FOG_DENSITY));
        accumCol += mask * eHitEmission * trans;
      }

			// normally we would 'break' here, but 'continue' allows more particles to be lit
      continue;
			//break;
    }

    if(sampleLight == TRUE)
      break;

    if(eHitType == DIFF) // Ideal DIFFUSE reflection
    {
      diffuseCount++;

      mask *= eHitColor;

      bounceIsSpecular = FALSE;

      if(diffuseCount == 1 && rand() < 0.5) {
        mask *= 2.0;
				// choose random Diffuse sample vector
        rayDirection = randomCosWeightedDirectionInHemisphere(nl);
        rayOrigin = x + nl * uEPS_intersect;
        continue;
      }

      if(rng() < 0.5) {
        chosenLight = quads[1];
        randPointOnLight.x = mix(chosenLight.v0.x, chosenLight.v2.x, clamp(rng(), 0.1, 0.9));
        randPointOnLight.y = chosenLight.v0.y;
        randPointOnLight.z = mix(chosenLight.v0.z, chosenLight.v2.z, clamp(rng(), 0.1, 0.9));
      }
      dirToLight = sampleQuadLight(x, nl, chosenLight, weight);
      mask *= diffuseCount == 1 ? 2.0 : 1.0;
      mask *= weight;
      mask *= 2.0;

      rayDirection = dirToLight;
      rayOrigin = x + nl * uEPS_intersect;

      sampleLight = TRUE;
      continue;
    }

    if(eHitType == SPEC)  // Ideal SPECULAR reflection
    {
      mask *= eHitColor;

      rayDirection = reflect(rayDirection, nl);
      rayOrigin = x + nl * uEPS_intersect;

			//bounceIsSpecular = TRUE; // turn on mirror caustics

      continue;
    }

    if(eHitType == REFR)  // Ideal dielectric REFRACTION
    {
      previousIntersecType = REFR;

      nc = 1.0; // IOR of Air
      nt = 1.5; // IOR of common Glass
      Re = calcFresnelReflectance(rayDirection, n, nc, nt, ratioIoR);
      Tr = 1.0 - Re;
      P = 0.25 + (0.5 * Re);
      RP = Re / P;
      TP = Tr / (1.0 - P);

      if(bounces == 0 && rand() < P) {
        mask *= RP;
        rayDirection = reflect(rayDirection, nl); // reflect ray from surface
        rayOrigin = x + nl * uEPS_intersect;

				//bounceIsSpecular = TRUE; // turn on reflecting caustics
        continue;
      }
			// transmit ray through surface

      mask *= TP;
      mask *= eHitColor;

      tdir = refract(rayDirection, nl, ratioIoR);
      rayDirection = tdir;
      rayOrigin = x - nl * uEPS_intersect;

			//bounceIsSpecular = TRUE; // turn on refracting caustics
      continue;

    } // end if (eHitType == REFR)

    if(eHitType == COAT)  // Diffuse object underneath with ClearCoat on top
    {
      nc = 1.0; // IOR of air
      nt = 1.4; // IOR of ClearCoat 
      Re = calcFresnelReflectance(rayDirection, nl, nc, nt, ratioIoR);
      Tr = 1.0 - Re;
      P = 0.25 + (0.5 * Re);
      RP = Re / P;
      TP = Tr / (1.0 - P);

			// choose either specular reflection or diffuse
      if(diffuseCount == 0 && rand() < P) {
        mask *= RP;
        rayDirection = reflect(rayDirection, nl); // reflect ray from surface
        rayOrigin = x + nl * uEPS_intersect;
        continue;
      }

      diffuseCount++;

      bounceIsSpecular = FALSE;

      mask *= TP;
      mask *= eHitColor;

      if(diffuseCount == 1 && rand() < 0.5) {
        mask *= 2.0;
				// choose random Diffuse sample vector
        rayDirection = randomCosWeightedDirectionInHemisphere(nl);
        rayOrigin = x + nl * uEPS_intersect;
        continue;
      }

      if(rng() < 0.5) {
        chosenLight = quads[1];
        randPointOnLight.x = mix(chosenLight.v0.x, chosenLight.v2.x, clamp(rng(), 0.1, 0.9));
        randPointOnLight.y = chosenLight.v0.y;
        randPointOnLight.z = mix(chosenLight.v0.z, chosenLight.v2.z, clamp(rng(), 0.1, 0.9));
      }
      dirToLight = sampleQuadLight(x, nl, chosenLight, weight);
      mask *= diffuseCount == 1 ? 2.0 : 1.0;
      mask *= weight;
      mask *= 2.0;

      rayDirection = dirToLight;
      rayOrigin = x + nl * uEPS_intersect;

      sampleLight = TRUE;
      continue;

    } //end if (eHitType == COAT)

  } // end for (int bounces = 0; bounces < 4; bounces++)

  return max(vec3(0), accumCol);

} // end vec3 CalculateRadiance( out vec3 objectNormal, out vec3 objectColor, out float objectID, out float pixelSharpness )

//-----------------------------------------------------------------------
void SetupScene(void)
//-----------------------------------------------------------------------
{
  vec3 z = vec3(0);
  vec3 L1 = vec3(1.0, 0.5, 0.5) * 1.0;//13.0;// White light
  vec3 L2 = vec3(1.0, 0.0, 0.0) * 40.0;//10.0;// red light
  vec3 L3 = vec3(0.1, 0.7, 1.0) * 105.0;//5.0; // Blue light

  // spheres[0] = Sphere(150.0, vec3(-600, 200, 600), L1, z, LIGHT);//spherical white Light1 
  // spheres[1] = Sphere(10.0, vec3(0, 30, 0), L2, z, LIGHT);//spherical yellow Light2
  // spheres[2] = Sphere(50.0, vec3(500, 250, -100), L3, z, LIGHT);//spherical blue Light3
  spheres[3] = Sphere(2000.0, vec3(0.0, 1000.0, 0.0), vec3(1.0, 1.0, 1.0), vec3(1.), DIFF);//Checkered Floor

  // spheres[4] = Sphere(16.5, vec3(-26.0, 17.2, 5.0), z, vec3(0.95, 0.95, 0.95), SPEC);//Mirror sphere

  quads[0] = Quad(vec3(-1, 0, 0), vec3(80, 50, -2), vec3(80, -2, 2), vec3(80, 2, 2), vec3(80, 2, -2), L1, z, LIGHT);// Rectangular Area Light

  // spheres[5] = Sphere(15.0, vec3(sin(mod(uTime * 0.3, TWO_PI)) * 80.0, 25, cos(mod(uTime * 0.1, TWO_PI)) * 80.0), z, vec3(1.0, 1.0, 1.0), REFR);//Glass sphere

  // ellipsoids[0] = Ellipsoid(vec3(30, 40, 16), vec3(cos(mod(uTime * 0.5, TWO_PI)) * 80.0, 5, -30), z, vec3(1.0, 0.765557, 0.336057), SPEC);//metallic gold ellipsoid

  // paraboloids[0] = Paraboloid(16.5, 50.0, vec3(20, 1, -50), z, vec3(1.0, 0.2, 0.7), REFR);//paraboloid

  // openCylinders[0] = OpenCylinder(15.0, 30.0, vec3(cos(mod(uTime * 0.1, TWO_PI)) * 100.0, 10, sin(mod(uTime * 0.4, TWO_PI)) * 100.0), z, vec3(0.9, 0.01, 0.01), REFR);//red glass open Cylinder

  // cappedCylinders[0] = CappedCylinder(14.0, vec3(-60, 0, 20), vec3(-60, 14, 20), z, vec3(0.05, 0.05, 0.05), COAT);//dark gray capped Cylinder

  // cones[0] = Cone(vec3(1, 20, -12), 15.0, vec3(1, 0, -12), 0.0, z, vec3(0.01, 0.1, 0.5), REFR);//blue Cone

  // capsules[0] = Capsule(vec3(80, 13, 15), 10.0, vec3(110, 15.8, 15), 10.0, z, vec3(1.0, 1.0, 1.0), COAT);//white Capsule

  // torii[0] = UnitTorus(0.75, z, vec3(0.955008, 0.637427, 0.538163), SPEC);//copper Torus

  boxes[0] = Box(vec3(-100.0, 3, -200.0), vec3(100.0, 3, 200.0), z, vec3(0.5), DIFF);//Glass Box
  boxes[1] = Box(vec3(56.0, 23.0, -66.0), vec3(94.0, 26.0, -124.0), z, vec3(0.0, 0.0, 0.0), DIFF);//Diffuse Box
}

// #include <pathtracing_main>

// tentFilter from Peter Shirley's 'Realistic Ray Tracing (2nd Edition)' book, pg. 60		
float tentFilter(float x) {
  return (x < 0.5) ? sqrt(2.0 * x) - 1.0 : 1.0 - sqrt(2.0 - (2.0 * x));
}

void main(void) {
  vec3 camRight = vec3(uCameraMatrix[0][0], uCameraMatrix[0][1], uCameraMatrix[0][2]);
  vec3 camUp = vec3(uCameraMatrix[1][0], uCameraMatrix[1][1], uCameraMatrix[1][2]);
  vec3 camForward = vec3(-uCameraMatrix[2][0], -uCameraMatrix[2][1], -uCameraMatrix[2][2]);

  // calculate unique seed for rng() function
  seed = uvec2(uFrameCounter, uFrameCounter + 1.0) * uvec2(gl_FragCoord);

	// initialize rand() variables
  counter = -1.0; // will get incremented by 1 on each call to rand()
  channel = 0; // the final selected color channel to use for rand() calc (range: 0 to 3, corresponds to R,G,B, or A)
  randNumber = 0.0; // the final randomly-generated number (range: 0.0 to 1.0)
  randVec4 = vec4(0); // samples and holds the RGBA blueNoise texture value for this pixel
  randVec4 = texelFetch(tBlueNoiseTexture, ivec2(mod(gl_FragCoord.xy + floor(uRandomVec2 * 256.0), 256.0)), 0);

  SetupScene();

	// NOTE: for this 'MultiSamples Per Frame' test demo, the edge detection and denoiser are temporarily disabled.
	// the following 4 variables are just acting as place holders that are passed in as arguments to the CalculateRadiance() function.
	// Any denoising/smoothness that you see is a direct result of the number of multi-samples layered on top of each other per frame, in Monte Carlo fashion.

	// Edge Detection - don't want to blur edges where either surface normals change abruptly (i.e. room wall corners), objects overlap each other (i.e. edge of a foreground sphere in front of another sphere right behind it),
	// or an abrupt color variation on the same smooth surface, even if it has similar surface normals (i.e. checkerboard pattern). Want to keep all of these cases as sharp as possible - no blur filter will be applied.
  vec3 objectNormal = vec3(0);
  vec3 objectColor = vec3(0);
  float objectID = -INFINITY;
  float pixelSharpness = 0.0;

	// multi-samples per frame
  vec4 currentPixel = vec4(0);
	// perform path tracing and get resulting pixel color
  for(int i = 0; i < int(uSamplesPerFrame); i++) {
    vec2 pixelOffset = vec2(tentFilter(rng()), tentFilter(rng())) * 0.5;

		// we must map pixelPos into the range -1.0 to +1.0
    vec2 pixelPos = ((gl_FragCoord.xy + pixelOffset) / uResolution) * 2.0 - 1.0;
    vec3 rayDir = normalize(pixelPos.x * camRight * uULen + pixelPos.y * camUp * uVLen + camForward);

		// depth of field
    vec3 focalPoint = uFocusDistance * rayDir;
    float randomAngle = rng() * TWO_PI; // pick random point on aperture
    float randomRadius = rng() * uApertureSize;
    vec3 randomAperturePos = (cos(randomAngle) * camRight + sin(randomAngle) * camUp) * sqrt(randomRadius);
		// point on aperture to focal point
    vec3 finalRayDir = normalize(focalPoint - randomAperturePos);

    rayOrigin = cameraPosition + randomAperturePos;
    rayDirection = finalRayDir;
    currentPixel += vec4(vec3(CalculateRadiance(objectNormal, objectColor, objectID, pixelSharpness)), 0.0);
    seed *= uvec2(3);
  }
  currentPixel /= uSamplesPerFrame; // average by number of samples

  vec4 previousPixel = texelFetch(tPreviousTexture, ivec2(gl_FragCoord.xy), 0);

  if(uCameraIsMoving) // camera is currently moving
  {
    previousPixel.rgb *= 0.5; // motion-blur trail amount (old image)
    currentPixel.rgb *= 0.5; // brightness of new image (noisy)
  } else {
    previousPixel.rgb *= uPreviousFrameBlendWeight; // motion-blur trail amount (old image)
    currentPixel.rgb *= (1.0 - uPreviousFrameBlendWeight); // brightness of new image (noisy)
  }

	// if current raytraced pixel didn't return any color value, just use the previous frame's pixel color
  if(currentPixel.rgb == vec3(0.0)) {
    currentPixel.rgb = previousPixel.rgb;
    previousPixel.rgb *= 0.5;
    currentPixel.rgb *= 0.5;
  }

  pc_fragColor = vec4(previousPixel.rgb + currentPixel.rgb, 1.0); // 1.01 is a signal to screenOutputShader to skip noise blur-filtering    
}

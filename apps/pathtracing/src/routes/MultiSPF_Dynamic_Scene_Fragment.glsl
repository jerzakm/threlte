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
#define N_QUADS 1
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

Sphere spheres[N_SPHERES];
Ellipsoid ellipsoids[N_ELLIPSOIDS];
Paraboloid paraboloids[N_PARABOLOIDS];
OpenCylinder openCylinders[N_OPENCYLINDERS];
CappedCylinder cappedCylinders[N_CAPPEDCYLINDERS];
Cone cones[N_CONES];
Capsule capsules[N_CAPSULES];
UnitTorus torii[N_TORII];
Box boxes[N_BOXES];

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

#include <pathtracing_sample_sphere_light>

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

//-------------------------------------------------------------------------------------------------------------------
float SceneIntersect(out int finalIsRayExiting)
//-------------------------------------------------------------------------------------------------------------------
{
  vec3 rObjOrigin, rObjDirection;
  vec3 n;
  float d, dt;
  float t = INFINITY;
  int isRayExiting = FALSE;
  int insideSphere = FALSE;
  int objectCount = 0;

  for(int i = 0; i < 16; i++) {
    if(dBoxTypes[i] < 0)
      break;

    if(dBoxTypes[i] > 0) {
      rObjOrigin = vec3(dBoxInvMatrices[i] * vec4(rayOrigin, 1.0));
      rObjDirection = vec3(dBoxInvMatrices[i] * vec4(rayDirection, 0.0));
      d = BoxIntersect(dBoxMinCorners[i], dBoxMaxCorners[i], rObjOrigin, rObjDirection, n, isRayExiting);
      if(d < t) {
        t = d;
        // hitNormal = n;
        hitNormal = transpose(mat3(dBoxInvMatrices[i])) * n;
        hitEmission = vec3(0.5);
        hitColor = dBoxColors[i];
        hitType = dBoxTypes[i];
        finalIsRayExiting = isRayExiting;
        hitObjectID = float(objectCount);
      }
      objectCount++;
    }
  }

  for(int i = 0; i < N_SPHERES; i++) {
    d = SphereIntersect(spheres[i].radius, spheres[i].position, rayOrigin, rayDirection);
    if(d < t) {
      t = d;
      hitNormal = (rayOrigin + rayDirection * t) - spheres[i].position;
      hitEmission = spheres[i].emission;
      hitColor = spheres[i].color;
      hitType = spheres[i].type;
      hitObjectID = float(objectCount);
    }
    objectCount++;
  }

  for(int i = 0; i < N_BOXES; i++) {
    d = BoxIntersect(boxes[i].minCorner, boxes[i].maxCorner, rayOrigin, rayDirection, n, isRayExiting);
    if(d < t) {
      t = d;
      hitNormal = n;
      hitEmission = boxes[i].emission;
      hitColor = boxes[i].color;
      hitType = boxes[i].type;
      finalIsRayExiting = isRayExiting;
      hitObjectID = float(objectCount);
    }
    objectCount++;
  }

  d = EllipsoidIntersect(ellipsoids[0].radii, ellipsoids[0].position, rayOrigin, rayDirection);
  if(d < t) {
    t = d;
    hitNormal = ((rayOrigin + rayDirection * t) -
      ellipsoids[0].position) / (ellipsoids[0].radii * ellipsoids[0].radii);
    hitEmission = ellipsoids[0].emission;
    hitColor = ellipsoids[0].color;
    hitType = ellipsoids[0].type;
    hitObjectID = float(objectCount);
  }
  objectCount++;

  d = ParaboloidIntersect(paraboloids[0].rad, paraboloids[0].height, paraboloids[0].pos, rayOrigin, rayDirection, n);
  if(d < t) {
    t = d;
    hitNormal = n;
    hitEmission = paraboloids[0].emission;
    hitColor = paraboloids[0].color;
    hitType = paraboloids[0].type;
    hitObjectID = float(objectCount);
  }
  objectCount++;

  d = OpenCylinderIntersect(openCylinders[0].position, openCylinders[0].position + vec3(0, 30, 30), openCylinders[0].radius, rayOrigin, rayDirection, n);
  if(d < t) {
    t = d;
    hitNormal = n;
    hitEmission = openCylinders[0].emission;
    hitColor = openCylinders[0].color;
    hitType = openCylinders[0].type;
    hitObjectID = float(objectCount);
  }
  objectCount++;

  d = CappedCylinderIntersect(cappedCylinders[0].cap1pos, cappedCylinders[0].cap2pos, cappedCylinders[0].radius, rayOrigin, rayDirection, n);
  if(d < t) {
    t = d;
    hitNormal = n;
    hitEmission = cappedCylinders[0].emission;
    hitColor = cappedCylinders[0].color;
    hitType = cappedCylinders[0].type;
    hitObjectID = float(objectCount);
  }
  objectCount++;

  d = ConeIntersect(cones[0].pos0, cones[0].radius0, cones[0].pos1, cones[0].radius1, rayOrigin, rayDirection, n);
  if(d < t) {
    t = d;
    hitNormal = n;
    hitEmission = cones[0].emission;
    hitColor = cones[0].color;
    hitType = cones[0].type;
    hitObjectID = float(objectCount);
  }
  objectCount++;

  d = CapsuleIntersect(capsules[0].pos0, capsules[0].radius0, capsules[0].pos1, capsules[0].radius1, rayOrigin, rayDirection, n);
  if(d < t) {
    t = d;
    hitNormal = n;
    hitEmission = capsules[0].emission;
    hitColor = capsules[0].color;
    hitType = capsules[0].type;
    hitObjectID = float(objectCount);
  }
  objectCount++;

  return t;

} // end float SceneIntersect(out int finalIsRayExiting)

//-----------------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------------------------------------
vec3 CalculateRadiance(out vec3 objectNormal, out vec3 objectColor, out float objectID, out float pixelSharpness)
//----------------------------------------------------------------------------------------------------------------------------------------------------
{
  vec3 accumCol = vec3(0);
  vec3 mask = vec3(1);
  vec3 reflectionMask = vec3(1);
  vec3 reflectionRayOrigin = vec3(0);
  vec3 reflectionRayDirection = vec3(0);
  vec3 checkCol0 = vec3(1);
  vec3 checkCol1 = vec3(0.5);
  vec3 tdir;
  vec3 x, n, nl;

  float t;
  float nc, nt, ratioIoR, Re, Tr;
	//float P, RP, TP;
  float weight;
  float thickness = 0.1;
  float roughness = 0.0;

  int diffuseCount = 0;
  int previousIntersecType = -100;
  hitType = -100;

  int coatTypeIntersected = FALSE;
  int bounceIsSpecular = TRUE;
  int sampleLight = FALSE;
  int isRayExiting = FALSE;
  int willNeedReflectionRay = FALSE;

  for(int bounces = 0; bounces < 8; bounces++) {
    previousIntersecType = hitType;

    t = SceneIntersect(isRayExiting);
    float roughness = 1.;

    if(t == INFINITY) {
      vec3 environmentCol = Get_HDR_Color(rayDirection);

			// looking directly at sky
      if(bounces == 0) {
        pixelSharpness = 1.01;

        accumCol += environmentCol;
        break;
      }

			// sun light source location in HDRI image is sampled by a diffuse surface
			// mask has already been down-weighted in this case
      if(sampleLight == TRUE) {
        accumCol += mask * environmentCol;
				//break;
      }

			// random diffuse bounce hits sky
      else if(bounceIsSpecular == FALSE) {
        weight = dot(rayDirection, uSunDirectionVector) < 0.98 ? 1.0 : 0.0;
        accumCol += mask * environmentCol * weight;

        if(bounces == 3)
          accumCol += mask * environmentCol * weight * 2.0; // ground beneath glass table

				//break;
      }

      if(bounceIsSpecular == TRUE) {
        if(coatTypeIntersected == TRUE) {
          if(dot(rayDirection, uSunDirectionVector) > 0.998)
            pixelSharpness = 1.01;
        } else
          pixelSharpness = 1.01;

        if(dot(rayDirection, uSunDirectionVector) > 0.8) {
          environmentCol = mix(vec3(1), environmentCol, clamp(pow(1.0 - roughness, 20.0), 0.0, 1.0));
        }

        accumCol += mask * environmentCol;
				//break;
      }

      if(willNeedReflectionRay == TRUE) {
        mask = reflectionMask;
        rayOrigin = reflectionRayOrigin;
        rayDirection = reflectionRayDirection;

        willNeedReflectionRay = FALSE;
        bounceIsSpecular = TRUE;
        sampleLight = FALSE;
        diffuseCount = 0;
        continue;
      }

			// reached the HDRI sky light, so we can exit
      break;

    } // end if (t == INFINITY)

		// useful data 
    n = normalize(hitNormal);
    nl = dot(n, rayDirection) < 0.0 ? n : -n;
    x = rayOrigin + rayDirection * t;

    if(bounces == 0) {
      objectNormal = nl;
      objectColor = hitColor;
      objectID = hitObjectID;
    }
    if(bounces == 1 && diffuseCount == 0 && coatTypeIntersected == FALSE) {
      objectNormal = nl;
    }

		// if we get here and sampleLight is still TRUE, shadow ray failed to find the light source 
		// the ray hit an occluding object along its way to the light
    if(sampleLight == TRUE) {
      if(willNeedReflectionRay == TRUE) {
        mask = reflectionMask;
        rayOrigin = reflectionRayOrigin;
        rayDirection = reflectionRayDirection;

        willNeedReflectionRay = FALSE;
        bounceIsSpecular = TRUE;
        sampleLight = FALSE;
        diffuseCount = 0;
        continue;
      }

      break;
    }

    if(hitType == DIFF || hitType == CHECK) // Ideal DIFFUSE reflection
    {
      if(hitType == CHECK) {
        float q = clamp(mod(dot(floor(x.xz * 0.04), vec2(1.0)), 2.0), 0.0, 1.0);
        hitColor = checkCol0 * q + checkCol1 * (1.0 - q);
      }
      if(diffuseCount == 0 && coatTypeIntersected == FALSE)
        objectColor = hitColor;

      diffuseCount++;

      mask *= hitColor;

      bounceIsSpecular = FALSE;

      if(diffuseCount == 1 && rand() < 0.5) {
        mask *= 2.0;
				// choose random Diffuse sample vector
        rayDirection = randomCosWeightedDirectionInHemisphere(nl);
        rayOrigin = x + nl * uEPS_intersect;
        continue;
      }

      rayDirection = randomDirectionInSpecularLobe(uSunDirectionVector, 0.07);
      rayOrigin = x + nl * uEPS_intersect;
      weight = max(0.0, dot(rayDirection, nl)) * 0.000015; // down-weight directSunLight contribution
      mask *= diffuseCount == 1 ? 2.0 : 1.0;
      mask *= weight;

      sampleLight = TRUE;
      continue;
    }

    if(hitType == SPEC)  // Ideal SPECULAR reflection
    {
      mask *= hitColor;

      rayDirection = randomDirectionInSpecularLobe(reflect(rayDirection, nl), roughness);
      rayOrigin = x + nl * uEPS_intersect;
      continue;
    }

    if(hitType == REFR)  // Ideal dielectric REFRACTION
    {
      pixelSharpness = diffuseCount == 0 && coatTypeIntersected == FALSE ? -1.0 : pixelSharpness;

      nc = 1.0; // IOR of Air
      nt = 1.5; // IOR of common Glass
      Re = calcFresnelReflectance(rayDirection, n, nc, nt, ratioIoR);
      Tr = 1.0 - Re;

      if(bounces == 0 || (bounces == 1 && hitObjectID != objectID && bounceIsSpecular == TRUE)) {
        reflectionMask = mask * Re;
        reflectionRayDirection = reflect(rayDirection, nl); // reflect ray from surface
        reflectionRayDirection = randomDirectionInSpecularLobe(reflectionRayDirection, roughness);
        reflectionRayOrigin = x + nl * uEPS_intersect;
        willNeedReflectionRay = TRUE;
      }

      if(Re == 1.0) {
        mask = reflectionMask;
        rayOrigin = reflectionRayOrigin;
        rayDirection = reflectionRayDirection;

        willNeedReflectionRay = FALSE;
        bounceIsSpecular = TRUE;
        sampleLight = FALSE;
        continue;
      }

			// transmit ray through surface
      mask *= Tr;

			// is ray leaving a solid object from the inside? 
			// If so, attenuate ray color with object color by how far ray has travelled through the medium
      if(isRayExiting == TRUE || (distance(n, nl) > 0.1)) {
        isRayExiting = FALSE;
        mask *= exp(log(hitColor) * thickness * t);
      } else
        mask *= hitColor;

      tdir = refract(rayDirection, nl, ratioIoR);
      rayDirection = randomDirectionInSpecularLobe(tdir, roughness * roughness);
      rayOrigin = x - nl * uEPS_intersect;

      continue;

    } // end if (hitType == REFR)

    if(hitType == COAT)  // Diffuse object underneath with ClearCoat on top (like car, or shiny pool ball)
    {
      coatTypeIntersected = TRUE;

      nc = 1.0; // IOR of Air
      nt = 1.5; // IOR of Clear Coat
      Re = calcFresnelReflectance(rayDirection, nl, nc, nt, ratioIoR);
      Tr = 1.0 - Re;

      if(bounces == 0 || (bounces == 1 && hitObjectID != objectID && bounceIsSpecular == TRUE)) {
        reflectionMask = mask * Re;
        reflectionRayDirection = reflect(rayDirection, nl); // reflect ray from surface
        reflectionRayDirection = randomDirectionInSpecularLobe(reflectionRayDirection, roughness);
        reflectionRayOrigin = x + nl * uEPS_intersect;
        willNeedReflectionRay = TRUE;
      }

      diffuseCount++;

      if(bounces == 0)
        mask *= Tr;
      mask *= hitColor;

      bounceIsSpecular = FALSE;

      if(diffuseCount == 1 && rand() < 0.5) {
        mask *= 2.0;
				// choose random Diffuse sample vector
        rayDirection = randomCosWeightedDirectionInHemisphere(nl);
        rayOrigin = x + nl * uEPS_intersect;
        continue;
      }

      rayDirection = randomDirectionInSpecularLobe(uSunDirectionVector, 0.07);
      rayOrigin = x + nl * uEPS_intersect;
      weight = max(0.0, dot(rayDirection, nl)) * 0.000015; // down-weight directSunLight contribution
      mask *= diffuseCount == 1 ? 2.0 : 1.0;
      mask *= weight;

      sampleLight = TRUE;
      continue;

    } //end if (hitType == COAT)

  } // end for (int bounces = 0; bounces < 5; bounces++)

  return max(vec3(0), accumCol);

} // end vec3 CalculateRadiance( out vec3 objectNormal, out vec3 objectColor, out float objectID, out float pixelSharpness )
// end vec3 CalculateRadiance( out vec3 objectNormal, out vec3 objectColor, out float objectID, out float pixelSharpness )

//-----------------------------------------------------------------------
void SetupScene(void)
//-----------------------------------------------------------------------
{
  vec3 z = vec3(0);
  vec3 L1 = vec3(1.0, 1.0, 1.0) * 93.0;//13.0;// White light
  vec3 L2 = vec3(1.0, 0.1, 0.1) * 4.0;//10.0;// Yellow light
  vec3 L3 = vec3(0.1, 0.7, 1.0) * 2.0;//5.0; // Blue light

  spheres[0] = Sphere(150.0, vec3(-600, 100, 600), L1, z, LIGHT);//spherical white Light1 
  spheres[1] = Sphere(100.0, vec3(300, 400, -300), L2, z, LIGHT);//spherical yellow Light2
  spheres[2] = Sphere(50.0, vec3(500, 250, -100), L3, z, LIGHT);//spherical blue Light3
  // spheres[3] = Sphere(2000.0, vec3(0.0, 1000.0, 0.0), vec3(1.0, 1.0, 1.0), vec3(1.), DIFF);//Checkered Floor

  // spheres[4] = Sphere(16.5, vec3(-26.0, 17.2, 5.0), z, vec3(0.95, 0.95, 0.95), SPEC);//Mirror sphere
  // spheres[5] = Sphere(15.0, vec3(sin(mod(uTime * 0.3, TWO_PI)) * 80.0, 25, cos(mod(uTime * 0.1, TWO_PI)) * 80.0), z, vec3(1.0, 1.0, 1.0), REFR);//Glass sphere

  // ellipsoids[0] = Ellipsoid(vec3(30, 40, 16), vec3(cos(mod(uTime * 0.5, TWO_PI)) * 80.0, 5, -30), z, vec3(1.0, 0.765557, 0.336057), SPEC);//metallic gold ellipsoid

  // paraboloids[0] = Paraboloid(16.5, 50.0, vec3(20, 1, -50), z, vec3(1.0, 0.2, 0.7), REFR);//paraboloid

  // openCylinders[0] = OpenCylinder(15.0, 30.0, vec3(cos(mod(uTime * 0.1, TWO_PI)) * 100.0, 10, sin(mod(uTime * 0.4, TWO_PI)) * 100.0), z, vec3(0.9, 0.01, 0.01), REFR);//red glass open Cylinder

  // cappedCylinders[0] = CappedCylinder(14.0, vec3(-60, 0, 20), vec3(-60, 14, 20), z, vec3(0.05, 0.05, 0.05), COAT);//dark gray capped Cylinder

  // cones[0] = Cone(vec3(1, 20, -12), 15.0, vec3(1, 0, -12), 0.0, z, vec3(0.01, 0.1, 0.5), REFR);//blue Cone

  // capsules[0] = Capsule(vec3(80, 13, 15), 10.0, vec3(110, 15.8, 15), 10.0, z, vec3(1.0, 1.0, 1.0), COAT);//white Capsule

  // torii[0] = UnitTorus(0.75, z, vec3(0.955008, 0.637427, 0.538163), SPEC);//copper Torus

  // boxes[0] = Box(vec3(-100.0, 3, -200.0), vec3(100.0, 3, 200.0), z, vec3(0.5), DIFF);//Glass Box
  // boxes[1] = Box(vec3(56.0, 23.0, -66.0), vec3(94.0, 26.0, -124.0), z, vec3(0.0, 0.0, 0.0), DIFF);//Diffuse Box
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

  pc_fragColor = vec4(previousPixel.rgb + currentPixel.rgb, 1.01); // 1.01 is a signal to screenOutputShader to skip noise blur-filtering    
}

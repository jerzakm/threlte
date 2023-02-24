uniform vec3 weights;
// uniform vec2 resolution;
// uniform vec2 texelSize;
// uniform float cameraNear;
// uniform float cameraFar;
// uniform float aspect;
// uniform float time;
// uniform sampler2D inputBuffer;
// uniform sampler2D depthBuffer;
// varying vec2 vUv;
// https://www.shadertoy.com/view/3dd3Wr



// Bird defines
#define SAMPLES 80  // HIGHER = NICER = SLOWER
#define DISTRIBUTION_BIAS 0.5 // between 0. and 1.
#define PIXEL_MULTIPLIER  2.5 // between 1. and 3. (keep low)
#define INVERSE_HUE_TOLERANCE 30.0 // (2. - 30.)
#define GOLDEN_ANGLE 2.3999632 //3PI-sqrt(5)PI
#define pow(a,b) pow(max(a,0.),b) // @morimea
mat2 sample2D = mat2(cos(GOLDEN_ANGLE),sin(GOLDEN_ANGLE),-sin(GOLDEN_ANGLE),cos(GOLDEN_ANGLE));
vec3 sirBirdDenoise(sampler2D imageTexture, in vec2 uv, in vec2 imageResolution) {
    
    vec3 denoisedColor           = vec3(0.);
    
    const float sampleRadius     = sqrt(float(SAMPLES));
    const float sampleTrueRadius = 0.5/(sampleRadius*sampleRadius);
    vec2        samplePixel      = vec2(1.0/imageResolution.x,1.0/imageResolution.y); 
    vec3        sampleCenter     = texture(imageTexture, uv).rgb;
    vec3        sampleCenterNorm = normalize(sampleCenter);
    float       sampleCenterSat  = length(sampleCenter);
    
    float  influenceSum = 0.0;
    float brightnessSum = 0.0;
    
    vec2 pixelRotated = vec2(0.,1.);
    
    for (float x = 0.0; x <= float(SAMPLES); x++) {
        
        pixelRotated *= sample2D;
        
        vec2  pixelOffset    = PIXEL_MULTIPLIER*pixelRotated*sqrt(x)*0.5;
        float pixelInfluence = 1.0-sampleTrueRadius*pow(dot(pixelOffset,pixelOffset),DISTRIBUTION_BIAS);
        pixelOffset *= samplePixel;
            
        vec3 thisDenoisedColor = 
            texture(imageTexture, uv + pixelOffset).rgb;

        pixelInfluence      *= pixelInfluence*pixelInfluence;
        /*
            HUE + SATURATION FILTER
        */
        pixelInfluence      *=   
            pow(0.5+0.5*dot(sampleCenterNorm,normalize(thisDenoisedColor)),INVERSE_HUE_TOLERANCE)
            * pow(1.0 - abs(length(thisDenoisedColor)-length(sampleCenterSat)),8.);
            
        influenceSum += pixelInfluence;
        denoisedColor += thisDenoisedColor*pixelInfluence;
    }
    
    return denoisedColor/influenceSum;
    
}


//bilateral
#define SIGMA 10.0
#define BSIGMA 0.5
#define MSIZE 15
#define USE_CONSTANT_KERNEL = true
#define SKIN_DETECTION
const bool GAMMA_CORRECTION = true; 
float kernel[MSIZE];

float normpdf(in float x, in float sigma) {
	return 0.39894 * exp(-0.5 * x * x/ (sigma * sigma)) / sigma;
}

float normpdf3(in vec3 v, in float sigma) {
	return 0.39894 * exp(-0.5 * dot(v,v) / (sigma * sigma)) / sigma;
}

float normalizeColorChannel(in float value, in float min, in float max) {
    return (value - min)/(max-min);
}


vec4 doBilateral(vec2 uv) {
  vec3 c = texture2D(inputBuffer, uv).rgb;
  const int kSize = (MSIZE - 1) / 2;
  vec3 final_colour = vec3(0.0);
  float Z = 0.0;

  #ifdef USE_CONSTANT_KERNEL
    // unfortunately, WebGL 1.0 does not support constant arrays...
    kernel[0] = kernel[14] = 0.031225216;
    kernel[1] = kernel[13] = 0.033322271;
    kernel[2] = kernel[12] = 0.035206333;
    kernel[3] = kernel[11] = 0.036826804;
    kernel[4] = kernel[10] = 0.038138565;
    kernel[5] = kernel[9]  = 0.039104044;
    kernel[6] = kernel[8]  = 0.039695028;
    kernel[7] = 0.039894000;
    float bZ = 0.2506642602897679;
  #else
    //create the 1-D kernel
    for (int j = 0; j <= kSize; ++j) {
      kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), SIGMA);
    }
      float bZ = 1.0 / normpdf(0.0, BSIGMA);
  #endif


  vec3 cc;
  float factor;
  //read out the texels
  for (int i=-kSize; i <= kSize; ++i) {
      for (int j=-kSize; j <= kSize; ++j) {
          cc = texture2D(inputBuffer, (uv*resolution + vec2(float(i),float(j)))/resolution).rgb;
          factor = normpdf3(cc-c, BSIGMA) * bZ * kernel[kSize+j] * kernel[kSize+i];
          Z += factor;
          if (GAMMA_CORRECTION) {
            final_colour += factor * pow(cc, vec3(2.2));
          } else {
            final_colour += factor * cc;
          }
      }
  }


  vec4 fCol;
  
  if (GAMMA_CORRECTION) {
    fCol = vec4(pow(final_colour / Z, vec3(1.0/2.2)), 1.0);
  } else {
    fCol = vec4(final_colour / Z, 1.0);
  }
  



  return fCol;
}




void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {

  // vec4 denoisedColor = smartDeNoise(inputBuffer, uv, 4.0, 2.0, .05) ;

  vec2 iChannel0Resolution = resolution*1.;
  vec4 color = texture2D(inputBuffer, uv);

  vec4 col = vec4(sirBirdDenoise(inputBuffer, uv, iChannel0Resolution).rgb, 1.);

  vec4 bilateralColor = doBilateral(uv);

	// outputColor = vec4(inputColor.rgb * weights, inputColor.a);	

  // outputColor = vec4(col,1.0);
  // outputColor = color;

  float w = 0.15;

  outputColor = (bilateralColor*w+col*(1.-w));

}
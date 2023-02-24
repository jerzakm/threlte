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

#define SAMPLES 80  // HIGHER = NICER = SLOWER
#define DISTRIBUTION_BIAS 0.1 // between 0. and 1.
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


void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {

  // vec4 denoisedColor = smartDeNoise(inputBuffer, uv, 4.0, 2.0, .05) ;

  vec2 iChannel0Resolution = resolution*1.;
  vec4 color = texture2D(inputBuffer, uv);

  vec3 col = sirBirdDenoise(inputBuffer, uv, iChannel0Resolution).rgb;

	// outputColor = vec4(inputColor.rgb * weights, inputColor.a);	

  outputColor = vec4(col,1.0);
  // outputColor = color;

}
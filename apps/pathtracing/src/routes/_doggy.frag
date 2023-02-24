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

vec4 blur5(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
  vec4 color = vec4(0.0);
  vec2 off1 = vec2(1.3333333333333333) * direction;
  color += texture2D(image, uv) * 0.29411764705882354;
  color += texture2D(image, uv + (off1 / resolution)) * 0.35294117647058826;
  color += texture2D(image, uv - (off1 / resolution)) * 0.35294117647058826;
  return color; 
}

vec4 blur9(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
  vec4 color = vec4(0.0);
  vec2 off1 = vec2(1.3846153846) * direction;
  vec2 off2 = vec2(3.2307692308) * direction;
  color += texture2D(image, uv) * 0.2270270270;
  color += texture2D(image, uv + (off1 / resolution)) * 0.3162162162;
  color += texture2D(image, uv - (off1 / resolution)) * 0.3162162162;
  color += texture2D(image, uv + (off2 / resolution)) * 0.0702702703;
  color += texture2D(image, uv - (off2 / resolution)) * 0.0702702703;
  return color;
}

vec4 blur13(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
  vec4 color = vec4(0.0);
  vec2 off1 = vec2(1.411764705882353) * direction;
  vec2 off2 = vec2(3.2941176470588234) * direction;
  vec2 off3 = vec2(5.176470588235294) * direction;
  color += texture2D(image, uv) * 0.1964825501511404;
  color += texture2D(image, uv + (off1 / resolution)) * 0.2969069646728344;
  color += texture2D(image, uv - (off1 / resolution)) * 0.2969069646728344;
  color += texture2D(image, uv + (off2 / resolution)) * 0.09447039785044732;
  color += texture2D(image, uv - (off2 / resolution)) * 0.09447039785044732;
  color += texture2D(image, uv + (off3 / resolution)) * 0.010381362401148057;
  color += texture2D(image, uv - (off3 / resolution)) * 0.010381362401148057;
  return color;
}

vec4 gaus(sampler2D tInput, vec2 uv, float Directions, float Quality, float Size){
  float Pi = 6.28318530718; // Pi*2
  vec2 Radius = Size/resolution;
  vec4 Color = texture2D(tInput, uv);
  // Blur calculations
  for( float d=0.0; d<Pi; d+=Pi/Directions)
  {
  for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
      {
    Color += texture2D( tInput, uv+vec2(cos(d),sin(d))*Radius*i);		
      }
  }

  Color/= Quality * Directions - 15.0;

    return Color;
}


vec4 greyscale(vec4 c){

  return vec4(vec3(c.r+c.g+c.b)/3., c.a);
}



void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {

  // vec4 denoisedColor = smartDeNoise(inputBuffer, uv, 4.0, 2.0, .05) ;

  vec3 oc = texture2D(inputBuffer, uv).rgb;

  float Directions = 16.0; // BLUR DIRECTIONS (Default 16.0 - More is better but slower)
  float Quality = 8.0; // BLUR QUALITY (Default 4.0 - More is better but slower)
  float Size = 8.0; // BLUR SIZE (Radius)

  vec4 g1 = gaus(inputBuffer, uv, Directions, Quality, 4.);  
  vec4 g2 = gaus(inputBuffer, uv, Directions, Quality, 1.);


  vec3 g = greyscale((g1-g2)).rgb * 8.;
  g*= g.r;
  g = g.r > 0.3? vec3(1.) : vec3(g.r);


  vec4 color = texture2D(inputBuffer, uv);
  // outputColor = vec4(oc, 1.);
  // outputColor = vec4(g.rgb*oc, 1.);
  outputColor = vec4(g.rgb, 1.);
  

}
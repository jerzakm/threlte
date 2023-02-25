<script lang="ts">
	import { initPathTracingCommons } from '$lib/pathTracingCommons';
	import { default as commonPathTracingVertex } from '$lib/pathTracingShaders/common_PathTracing_Vertex.glsl?raw';
	import { default as ScreenCopy_Fragment } from '$lib/pathTracingShaders/ScreenCopy_Fragment.glsl?raw';
	import { default as ScreenOutput_Fragment } from '$lib/pathTracingShaders/ScreenOutput_Fragment.glsl?raw';
	import { T, useFrame, useThrelte } from '@threlte/core';
	import * as THREE from 'three';
	import type { MeshBasicMaterial, OrthographicCamera, PerspectiveCamera } from 'three';
	import { default as scenePathTracingShader } from './MultiSPF_Dynamic_Scene_Fragment.glsl?raw';

	import type { Mesh } from 'three';
	import { sharedState } from '$lib/state';
	import { pathTracingState } from '$lib/state';
	import { RGBELoader } from 'three/examples/jsm/loaders/RGBELoader';

	const {
		sceneInitiated,
		pathTracingScene,
		screenCopyScene,
		screenOutputScene,
		outputCamera,
		sceneCamera
	} = sharedState;

	const { pathTracingBoxes } = pathTracingState;

	initPathTracingCommons();
	const PIXEL_RATIO = 1;
	const SAMPLES_PER_FRAME = 4;
	const BLEND_WEIGHT = 0.2;
	const EPS_intersect = 0.01;

	let SCREEN_WIDTH;
	let SCREEN_HEIGHT;
	let context;

	let pathTracingUniforms: any = {};
	let screenCopyUniforms: any;
	let screenOutputUniforms: any;
	let pathTracingDefines: any;
	let demoFragmentShaderFileName;
	let pathTracingMesh: Mesh;
	let pathTracingRenderTarget: any;
	let screenCopyRenderTarget: any;

	let quadCamera: OrthographicCamera;
	let worldCamera: PerspectiveCamera;

	let clock: any;
	let frameTime: any;
	let elapsedTime: any;
	let sceneIsDynamic = true;
	let fovScale;

	let apertureSize = 0.0;
	let focusDistance = 132.0;
	let sampleCounter = 0.0; // will get increased by 1 in animation loop before rendering
	let frameCounter = 1.0; // 1 instead of 0 because it is used as a rng() seed in pathtracing shader
	let cameraIsMoving = false;
	let cameraRecentlyMoving = false;

	let blueNoiseTexture;
	let useToneMapping = true;
	let allowOrthographicCamera = true;
	let pixelEdgeSharpness = 1.0;
	let edgeSharpenSpeed = 0.05;
	let filterDecaySpeed = 0.0002;

	let orthographicCamera_ToggleController: any;

	// the following variables will be used to calculate rotations and directions from the camera
	let cameraWorldQuaternion = new THREE.Quaternion(); //for rotating scene objects to match camera's current rotation

	let mouseControl = true;

	const { renderer, composer } = useThrelte();

	function onWindowResize(event: any) {
		SCREEN_WIDTH = window.innerWidth;
		SCREEN_HEIGHT = window.innerHeight;

		composer?.renderer.setSize(SCREEN_WIDTH, SCREEN_HEIGHT);
		composer?.renderer.setPixelRatio(PIXEL_RATIO);

		pathTracingUniforms.uResolution.value.x = SCREEN_WIDTH;
		pathTracingUniforms.uResolution.value.y = SCREEN_HEIGHT;

		pathTracingRenderTarget.setSize(SCREEN_WIDTH, SCREEN_HEIGHT);
		screenCopyRenderTarget.setSize(SCREEN_WIDTH, SCREEN_HEIGHT);

		worldCamera.aspect = SCREEN_WIDTH / SCREEN_HEIGHT;
		// the following is normally used with traditional rasterized rendering, but it is not needed for our fragment shader raytraced rendering
		///worldCamera.updateProjectionMatrix();

		// the following scales all scene objects by the worldCamera's field of view,
		// taking into account the screen aspect ratio and multiplying the uniform uULen,
		// the x-coordinate, by this ratio
		fovScale = worldCamera.fov * 0.5 * (Math.PI / 180.0);
		pathTracingUniforms.uVLen.value = Math.tan(fovScale);
		pathTracingUniforms.uULen.value = pathTracingUniforms.uVLen.value * worldCamera.aspect;
	} // end function onWindowResize( event )

	function init() {
		renderer.debug.checkShaderErrors = true;
		renderer.autoClear = false;
		renderer.toneMapping = THREE.ReinhardToneMapping;
		context = renderer?.getContext();
		context?.getExtension('EXT_color_buffer_float');

		clock = new THREE.Clock();

		$pathTracingScene?.add(worldCamera);

		// setup render targets...
		pathTracingRenderTarget = new THREE.WebGLRenderTarget(
			context.drawingBufferWidth,
			context.drawingBufferHeight,
			{
				minFilter: THREE.NearestFilter,
				magFilter: THREE.NearestFilter,
				format: THREE.RGBAFormat,
				type: THREE.FloatType,
				depthBuffer: false,
				stencilBuffer: false
			}
		);
		pathTracingRenderTarget.texture.generateMipmaps = false;

		screenCopyRenderTarget = new THREE.WebGLRenderTarget(
			context.drawingBufferWidth,
			context.drawingBufferHeight,
			{
				minFilter: THREE.NearestFilter,
				magFilter: THREE.NearestFilter,
				format: THREE.RGBAFormat,
				type: THREE.FloatType,
				depthBuffer: false,
				stencilBuffer: false
			}
		);
		screenCopyRenderTarget.texture.generateMipmaps = false;

		// blueNoise texture used in all demos
		blueNoiseTexture = new THREE.TextureLoader().load('textures/BlueNoise_RGBA256.png');
		blueNoiseTexture.wrapS = THREE.RepeatWrapping;
		blueNoiseTexture.wrapT = THREE.RepeatWrapping;
		blueNoiseTexture.flipY = false;
		blueNoiseTexture.minFilter = THREE.NearestFilter;
		blueNoiseTexture.magFilter = THREE.NearestFilter;
		blueNoiseTexture.generateMipmaps = false;

		// setup scene/demo-specific objects, variables, GUI elements, and data
		initSceneData();

		if (!allowOrthographicCamera && !mouseControl) {
			orthographicCamera_ToggleController.domElement.hidden = true;
			orthographicCamera_ToggleController.domElement.remove();
		}

		// setup screen-size quad geometry and shaders....

		// this full-screen quad mesh performs the path tracing operations and produces a screen-sized image

		pathTracingUniforms.tPreviousTexture = { type: 't', value: screenCopyRenderTarget.texture };
		pathTracingUniforms.tBlueNoiseTexture = { type: 't', value: blueNoiseTexture };

		pathTracingUniforms.uCameraMatrix = { type: 'm4', value: new THREE.Matrix4() };

		pathTracingUniforms.uResolution = { type: 'v2', value: new THREE.Vector2() };
		pathTracingUniforms.uRandomVec2 = { type: 'v2', value: new THREE.Vector2() };

		pathTracingUniforms.dBoxMinCorners = { value: [-10, -10, -10] };
		pathTracingUniforms.dBoxMaxCorners = { value: [10, 10, 10] };
		pathTracingUniforms.dBoxTypes = { value: [1] };

		pathTracingUniforms.uEPS_intersect = { type: 'f', value: EPS_intersect };
		pathTracingUniforms.uTime = { type: 'f', value: 0.0 };
		pathTracingUniforms.uSampleCounter = { type: 'f', value: 0.0 }; //0.0
		pathTracingUniforms.uPreviousSampleCount = { type: 'f', value: 1.0 };
		pathTracingUniforms.uFrameCounter = { type: 'f', value: 1.0 }; //1.0
		pathTracingUniforms.uULen = { type: 'f', value: 1.0 };
		pathTracingUniforms.uVLen = { type: 'f', value: 1.0 };
		pathTracingUniforms.uApertureSize = { type: 'f', value: apertureSize };
		pathTracingUniforms.uFocusDistance = { type: 'f', value: focusDistance };

		pathTracingUniforms.uCameraIsMoving = { type: 'b1', value: false };
		pathTracingUniforms.uUseOrthographicCamera = { type: 'b1', value: false };

		// pathTracingUniforms.minCorner = {
		// 	t: 'v3',
		// 	value: new Vector3(0, 0, 0)
		// };
		// pathTracingUniforms.maxCorner = {
		// 	t: 'v3',
		// 	value: new Vector3(20, 20, -20)
		// };
		// pathTracingUniforms.emission = {
		// 	t: 'v3',
		// 	value: new Vector3(0.5, 0.5, 0.5)
		// };
		// pathTracingUniforms.color = {
		// 	t: 'v3',
		// 	value: new Vector3(0.5, 0.25, 0)
		// };

		pathTracingDefines = {
			//NUMBER_OF_TRIANGLES: total_number_of_triangles
		};

		worldCamera.add(pathTracingMesh);

		screenCopyUniforms = {
			tPathTracedImageTexture: { type: 't', value: pathTracingRenderTarget.texture }
		};

		screenOutputUniforms = {
			tPathTracedImageTexture: { type: 't', value: pathTracingRenderTarget.texture },
			uSampleCounter: { type: 'f', value: 0.0 },
			uOneOverSampleCounter: { type: 'f', value: 0.0 },
			uPixelEdgeSharpness: { type: 'f', value: pixelEdgeSharpness },
			uEdgeSharpenSpeed: { type: 'f', value: edgeSharpenSpeed },
			uFilterDecaySpeed: { type: 'f', value: filterDecaySpeed },
			uSceneIsDynamic: { type: 'b1', value: sceneIsDynamic },
			uUseToneMapping: { type: 'b1', value: useToneMapping }
		};

		const hdrLoader = new RGBELoader();
		hdrLoader.type = THREE.FloatType; // override THREE's default of HalfFloatType

		// const hdrPath = 'textures/daytime.hdr';
		const hdrPath = 'shanghai_riverside_1k.hdr';

		const sunDirection = new THREE.Vector3();

		// sunDirection.set(Math.cos(sunAngle) * 1.2, Math.sin(sunAngle), -Math.cos(sunAngle) * 3.0);
		// sunDirection.normalize();

		const hdrTexture = hdrLoader.load(hdrPath, function (texture, textureData) {
			texture.encoding = THREE.LinearEncoding;
			texture.minFilter = THREE.LinearFilter;
			texture.magFilter = THREE.LinearFilter;
			texture.generateMipmaps = false;
			texture.flipY = false;

			const hdrImgWidth = texture.image.width;
			const hdrImgHeight = texture.image.height;
			const hdrImgData = texture.image.data;
			let dataLength = hdrImgData.length;
			let red, green, blue;

			let texel = 0;
			let max = 0;
			for (let i = 0; i < dataLength; i += 4) {
				red = hdrImgData[i + 0];
				green = hdrImgData[i + 1];
				blue = hdrImgData[i + 2];

				if (max < red) {
					texel = i;
					max = red;
				}
				if (max < green) {
					texel = i;
					max = green;
				}
				if (max < blue) {
					texel = i;
					max = blue;
				}
			}

			console.log('brightest texel index: ' + texel + ' | max luminance value: ' + max);
			// the raw flat array has 4 elements (R,G,B,A) for every single pixel, but we just want the index of the brightest pixel
			// so divide the brightest pixel array index by 4, in order to get back to the '0 to hdrImgWidth*hdrImgHeight' range
			texel /= 4;

			// map this texel's 1D array index into 2D (x and y) coordinates
			const brightestPixelX = texel % hdrImgWidth;
			const brightestPixelY = Math.floor(texel / hdrImgWidth);

			console.log('brightestPixelX: ' + brightestPixelX + ' brightestPixelY: ' + brightestPixelY); // for debug

			/*  
    HDRI image dimensions: (hdrImgWidth x hdrImgHeight)
    center of brightest pixel location: (brightestPixelX, brightestPixelY) 
    now normalize into float (u,v) texture coords, range: (0.0-1.0, 0.0-1.0)
    HDRI_bright_u = brightestPixelX / hdrImgWidth
    HDRI_bright_v = brightestPixelY / hdrImgHeight
  	
    Must map these brightest-light texture location(u, v) coordinates to Spherical coordinates(phi, theta):
    phi   = HDRI_bright_v * PI   note: V is used for phi
    theta = HDRI_bright_u * 2PI  note: U is used for theta
    lastly, convert Spherical coordinates into 3D Cartesian coordinates(x, y, z):
    sunDirectionVector.setFromSphericalCoords(1, phi, theta);
    */

			const HDRI_bright_u = brightestPixelX / hdrImgWidth;
			const HDRI_bright_v = brightestPixelY / hdrImgHeight;

			const phi = HDRI_bright_v * Math.PI; // use 'v'
			const theta = HDRI_bright_u * 2 * Math.PI; // use 'u'

			sunDirection.setFromSphericalCoords(1, phi, theta); // 1 = radius of 1, or unit sphere
			// finally, x must be negated, I believe because of three.js' R-handed coordinate system
			sunDirection.x *= -1;
		});

		// Environment variables
		const skyLightIntensity = 2.0,
			sunLightIntensity = 2.0,
			sunColor = [1.0, 0.98, 0.92],
			sunAngle = Math.PI / 2.5,
			hdrExposure = 3.0;

		pathTracingUniforms.tHDRTexture = { value: hdrTexture };
		pathTracingUniforms.uSkyLightIntensity = { value: skyLightIntensity };
		pathTracingUniforms.uSunLightIntensity = { value: sunLightIntensity };
		pathTracingUniforms.uSunColor = { value: new THREE.Color().fromArray(sunColor.map((x) => x)) };
		pathTracingUniforms.uSunDirectionVector = { value: sunDirection };
		pathTracingUniforms.uHDRI_Exposure = { value: hdrExposure };

		window.addEventListener('resize', onWindowResize, false);
		// this 'jumpstarts' the initial dimensions and parameters for the window and renderer
		onWindowResize();

		sharedState.sceneInitiated.set(true);
	} // end function initTHREEjs()

	function animate() {
		frameTime = clock.getDelta();

		elapsedTime = clock.getElapsedTime() % 1000;

		// reset flags
		cameraIsMoving = false;

		// the following gives us a rotation quaternion (4D vector), which will be useful for
		// rotating scene objects to match the camera's rotation
		worldCamera.getWorldQuaternion(cameraWorldQuaternion);
		// update scene/demo-specific input(if custom), variables and uniforms every animation frame
		updateVariablesAndUniforms();

		// now update uniforms that are common to all scenes
		if (!cameraIsMoving) {
			if (sceneIsDynamic) sampleCounter = 1.0; // reset for continuous updating of image
			else sampleCounter += 1.0; // for progressive refinement of image

			frameCounter += 1.0;

			cameraRecentlyMoving = false;
		}

		if (cameraIsMoving) {
			frameCounter += 1.0;

			if (!cameraRecentlyMoving) {
				// record current sampleCounter before it gets set to 1.0 below
				pathTracingUniforms.uPreviousSampleCount.value = sampleCounter;
				frameCounter = 1.0;
				cameraRecentlyMoving = true;
			}

			sampleCounter = 1.0;
		}

		pathTracingUniforms.uTime.value = elapsedTime;
		pathTracingUniforms.uCameraIsMoving.value = cameraIsMoving;
		pathTracingUniforms.uSampleCounter.value = sampleCounter;
		pathTracingUniforms.uFrameCounter.value = frameCounter;
		pathTracingUniforms.uRandomVec2.value.set(Math.random(), Math.random());

		// CAMERA
		worldCamera.updateMatrixWorld(true);
		pathTracingUniforms.uCameraMatrix.value.copy(worldCamera.matrixWorld);

		screenOutputUniforms.uSampleCounter.value = sampleCounter;
		// PROGRESSIVE SAMPLE WEIGHT (reduces intensity of each successive animation frame's image)
		screenOutputUniforms.uOneOverSampleCounter.value = 1.0 / sampleCounter;

		// RENDERING in 3 steps

		// STEP 1
		// Perform PathTracing and Render(save) into pathTracingRenderTarget, a full-screen texture.
		// Read previous screenCopyRenderTarget(via texelFetch inside fragment shader) to use as a new starting point to blend with
		renderer.setRenderTarget(pathTracingRenderTarget);
		renderer.render($pathTracingScene, worldCamera);

		// STEP 2
		// Render(copy) the pathTracingScene output(pathTracingRenderTarget above) into screenCopyRenderTarget.
		// This will be used as a new starting point for Step 1 above (essentially creating ping-pong buffers)
		renderer.setRenderTarget(screenCopyRenderTarget);
		renderer.render($screenCopyScene, quadCamera);

		// STEP 3
		// Render full screen quad with generated pathTracingRenderTarget in STEP 1 above.
		// After applying tonemapping and gamma-correction to the image, it will be shown on the screen as the final accumulated output
		// renderer.setRenderTarget(null);
		// renderer.render($screenOutputScene, quadCamera);
	} // end function animate()

	// scene/demo-specific variables go here

	// called automatically from within initTHREEjs() function (located in InitCommon.js file)
	function initSceneData() {
		demoFragmentShaderFileName = 'MultiSPF_Dynamic_Scene_Fragment.glsl';

		// scene/demo-specific three.js objects setup goes here
		sceneIsDynamic = true;

		// position and orient camera
		// scene/demo-specific uniforms go here

		pathTracingUniforms.uSamplesPerFrame = { value: SAMPLES_PER_FRAME };
		pathTracingUniforms.uPreviousFrameBlendWeight = { value: BLEND_WEIGHT };
	}

	let userBox: Mesh;

	$: {
		console.log(userBox);
	}

	function updateVariablesAndUniforms() {
		const dBoxMinCorners: number[] = [];
		const dBoxMaxCorners: number[] = [];
		const dBoxTypes: number[] = [];
		const dBoxColors: number[] = [];
		const dBoxInvMatrices: number[] = [];
		const bArr = Object.values($pathTracingBoxes);
		bArr.map((box) => {
			dBoxMinCorners.push(...box.minCorner);
			dBoxMaxCorners.push(...box.maxCorner);
			dBoxColors.push(...box.color);
			dBoxInvMatrices.push(...box.invMatrix);
			dBoxTypes.push(box.type);
		});

		pathTracingUniforms.dBoxMinCorners = { value: dBoxMinCorners };
		pathTracingUniforms.dBoxMaxCorners = { value: dBoxMaxCorners };
		pathTracingUniforms.dBoxTypes = { value: dBoxTypes };
		pathTracingUniforms.dBoxColors = { value: dBoxColors };
		pathTracingUniforms.dBoxInvMatrices = { value: dBoxInvMatrices };
	}

	$: {
		if (renderer && $screenOutputScene) {
			init(); // init app and start animating
			outputCamera.set(quadCamera);
			sceneCamera.set(worldCamera);
		}
	}

	useFrame(() => {
		if ($sceneInitiated) {
			animate();
		}
	});
</script>

<T.OrthographicCamera args={[-1, 1, 1, -1, 0, 1]} bind:ref={quadCamera} makeDefault />

<T.PerspectiveCamera
	args={[60, window.innerWidth / window.innerHeight, 1, 1000]}
	bind:ref={worldCamera}
	position.x={50}
	position.y={50}
	position.z={-70}
	rotation={[-2.5, 0.4, 2.8]}
/>

<T.Scene bind:ref={$pathTracingScene}>
	<T.Mesh bind:ref={pathTracingMesh}>
		<T.ShaderMaterial
			uniforms={pathTracingUniforms}
			defines={pathTracingDefines}
			vertexShader={commonPathTracingVertex}
			fragmentShader={scenePathTracingShader}
			depthTest={false}
			depthWrite={false}
		/>
		<T.PlaneGeometry args={[2, 2]} />
	</T.Mesh>
	<slot />
</T.Scene>
<T.Scene bind:ref={$screenCopyScene}>
	<T.Mesh>
		<T.ShaderMaterial
			uniforms={screenCopyUniforms}
			vertexShader={commonPathTracingVertex}
			fragmentShader={ScreenCopy_Fragment}
			depthTest={false}
			depthWrite={false}
		/>
		<T.PlaneGeometry args={[2, 2]} />
	</T.Mesh>
</T.Scene>

<T.Scene bind:ref={$screenOutputScene}>
	<T.Mesh position.x={10}>
		<T.ShaderMaterial
			uniforms={screenOutputUniforms}
			vertexShader={commonPathTracingVertex}
			fragmentShader={ScreenOutput_Fragment}
			depthTest={false}
			depthWrite={false}
		/>
		<T.PlaneGeometry args={[2, 2]} />
	</T.Mesh>
</T.Scene>

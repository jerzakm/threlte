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
	import { Vector3 } from 'three';

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
	const SAMPLES_PER_FRAME = 8;
	const BLEND_WEIGHT = 0.6;
	const EPS_intersect = 0.5;

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
	let sceneIsDynamic = false;
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
		const dBoxMinCorners = [];
		const dBoxMaxCorners = [];
		const dBoxTypes = [];
		const dBoxColors = [];
		const bArr = Object.values($pathTracingBoxes);
		bArr.map((box) => {
			dBoxMinCorners.push(...box.minCorner);
			dBoxMaxCorners.push(...box.maxCorner);
			dBoxColors.push(...box.color);
			dBoxTypes.push(box.type);
		});

		pathTracingUniforms.dBoxMinCorners = { value: dBoxMinCorners };
		pathTracingUniforms.dBoxMaxCorners = { value: dBoxMaxCorners };
		pathTracingUniforms.dBoxTypes = { value: dBoxTypes };
		pathTracingUniforms.dBoxColors = { value: dBoxColors };
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
	position.y={10}
	position.z={60}
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

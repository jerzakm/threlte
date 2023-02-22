<script lang="ts">
	import { initPathTracingCommons } from '$lib/pathTracingCommons';
	import { useThrelte, T, useFrame } from '@threlte/core';
	import * as THREE from 'three';
	import { default as commonPathTracingVertex } from '$lib/pathTracingShaders/common_PathTracing_Vertex.glsl?raw';
	import { default as ScreenCopy_Fragment } from '$lib/pathTracingShaders/ScreenCopy_Fragment.glsl?raw';
	import { default as ScreenOutput_Fragment } from '$lib/pathTracingShaders/ScreenOutput_Fragment.glsl?raw';
	import { default as scenePathTracingShader } from './MultiSPF_Dynamic_Scene_Fragment.glsl?raw';
	import { Vector2, type OrthographicCamera, type PerspectiveCamera, type Scene } from 'three';

	import { sharedState } from './state';
	import type { Mesh } from 'three';
	import { Object3D } from 'three';

	const {
		sceneInitiated,
		pathTracingScene,
		screenCopyScene,
		screenOutputScene,
		outputCamera,
		sceneCamera
	} = sharedState;

	initPathTracingCommons();
	const PIXEL_RATIO = 0.75;
	const SAMPLES_PER_FRAME = 8;
	const BLEND_WEIGHT = 0.7;
	const EPS_intersect = 0.5;

	let SCREEN_WIDTH;
	let SCREEN_HEIGHT;
	let context;
	let controls: any;

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
	let cameraFlightSpeed = 60;
	let cameraRotationSpeed = 1;
	let fovScale;

	let apertureSize = 0.0;
	let focusDistance = 132.0;
	let TWO_PI = Math.PI * 2;
	let sampleCounter = 0.0; // will get increased by 1 in animation loop before rendering
	let frameCounter = 1.0; // 1 instead of 0 because it is used as a rng() seed in pathtracing shader
	let cameraIsMoving = false;
	let cameraRecentlyMoving = false;
	let isPaused = true;
	let oldYawRotation: any;
	let oldPitchRotation: any;

	let blueNoiseTexture;
	let useToneMapping = true;
	let allowOrthographicCamera = true;
	let pixelEdgeSharpness = 1.0;
	let edgeSharpenSpeed = 0.05;
	let filterDecaySpeed = 0.0002;

	let ableToEngagePointerLock = true;
	let orthographicCamera_ToggleController: any;

	// the following variables will be used to calculate rotations and directions from the camera
	let cameraDirectionVector = new THREE.Vector3(); //for moving where the camera is looking
	let cameraRightVector = new THREE.Vector3(); //for strafing the camera right and left
	let cameraUpVector = new THREE.Vector3(); //for moving camera up and down
	let cameraWorldQuaternion = new THREE.Quaternion(); //for rotating scene objects to match camera's current rotation
	let cameraControlsObject: any; //for positioning and moving the camera itself
	let cameraControlsYawObject: any; //allows access to control camera's left/right movements through mobile input
	let cameraControlsPitchObject: any; //allows access to control camera's up/down movements through mobile input

	let PI_2 = Math.PI / 2; //used by controls below

	let mouseControl = true;
	let pointerlockChange;

	const setupControls = (camera: PerspectiveCamera) => {
		//
		camera.rotation.set(0, 0, 0);
		camera.position.set(0, 20, 0);
	};

	const { renderer, composer } = useThrelte();

	function onWindowResize(event: any) {
		// the following change to document.body.clientWidth and Height works better for mobile, especially iOS
		// suggestion from Github user q750831855  - Thank you!
		SCREEN_WIDTH = window.innerWidth;
		SCREEN_HEIGHT = window.innerHeight;

		// renderer?.setPixelRatio(PIXEL_RATIO);
		// renderer?.setSize(SCREEN_WIDTH, SCREEN_HEIGHT);
		composer?.renderer.setSize(SCREEN_WIDTH, SCREEN_HEIGHT);
		composer?.renderer.setPixelRatio(PIXEL_RATIO);

		console.log(composer?.renderer.getSize(new Vector2()));

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
		initTHREEjs(); // boilerplate: init necessary three.js items and scene/demo-specific objects
		window.addEventListener('resize', onWindowResize, false);
	} // end function init()

	function initTHREEjs() {
		renderer.debug.checkShaderErrors = true;
		renderer.autoClear = false;
		renderer.toneMapping = THREE.ReinhardToneMapping;
		context = renderer?.getContext();
		context?.getExtension('EXT_color_buffer_float');

		clock = new THREE.Clock();

		// quadCamera is simply the camera to help render the full screen quad (2 triangles),
		// hence the name.  It is an Orthographic camera that sits facing the view plane, which serves as
		// the window into our 3d world. This camera will not move or rotate for the duration of the app.

		// worldCamera is the dynamic camera 3d object that will be positioned, oriented and
		// constantly updated inside the 3d scene.  Its view will ultimately get passed back to the
		// stationary quadCamera, which renders the scene to a fullscreen quad (made up of 2 large triangles).

		setupControls(worldCamera);

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

		// this 'jumpstarts' the initial dimensions and parameters for the window and renderer
		onWindowResize();

		sharedState.sceneInitiated.set(true);
	} // end function initTHREEjs()

	function animate() {
		frameTime = clock.getDelta();

		elapsedTime = clock.getElapsedTime() % 1000;

		// reset flags
		cameraIsMoving = false;

		// this gives us a vector in the direction that the camera is pointing,
		// which will be useful for moving the camera 'forward' and shooting projectiles in that direction

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
	let torusObject;
	let torusRotationAngle = 0;

	// called automatically from within initTHREEjs() function (located in InitCommon.js file)
	function initSceneData() {
		demoFragmentShaderFileName = 'MultiSPF_Dynamic_Scene_Fragment.glsl';

		// scene/demo-specific three.js objects setup goes here
		sceneIsDynamic = true;

		// Torus Object
		torusObject = new THREE.Object3D();
		$pathTracingScene?.add(torusObject);

		torusObject.position.set(-60, 18, 50);
		torusObject.scale.set(11.5, 11.5, 11.5);

		// position and orient camera
		// scene/demo-specific uniforms go here

		pathTracingUniforms.uTorusInvMatrix = { value: new THREE.Matrix4() };
		pathTracingUniforms.uSamplesPerFrame = { value: SAMPLES_PER_FRAME };
		pathTracingUniforms.uPreviousFrameBlendWeight = { value: BLEND_WEIGHT };
	}

	function updateVariablesAndUniforms() {
		// if GUI has been used, update

		// TORUS
		torusRotationAngle += 1.5 * frameTime;
		torusRotationAngle %= TWO_PI;
		torusObject.rotation.set(0, torusRotationAngle, 0);
		// torusObject.updateMatrixWorld(true); // 'true' forces immediate matrix update
		pathTracingUniforms.uTorusInvMatrix.value.copy(torusObject.matrixWorld).invert();
	}

	$: {
		if (renderer && $screenOutputScene) {
			init(); // init app and start animating
			outputCamera.set(quadCamera);
			sceneCamera.set(worldCamera);
		}
	}

	useFrame(() => {
		// everything is set up, now we can start animating

		if ($sceneInitiated) {
			animate();
		}
	});
</script>

<T.OrthographicCamera args={[-1, 1, 1, -1, 0, 1]} bind:ref={quadCamera} makeDefault />

<T.PerspectiveCamera
	args={[60, window.innerWidth / window.innerHeight, 1, 1000]}
	bind:ref={worldCamera}
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

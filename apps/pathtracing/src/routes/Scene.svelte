<script lang="ts">
	import { initPathTracingCommons } from '$lib/pathTracingCommons';
	import { useThrelte, T, useFrame } from '@threlte/core';
	import * as THREE from 'three';
	import { default as commonPathTracingVertex } from '$lib/pathTracingShaders/common_PathTracing_Vertex.glsl?raw';
	import { default as ScreenCopy_Fragment } from '$lib/pathTracingShaders/ScreenCopy_Fragment.glsl?raw';
	import { default as ScreenOutput_Fragment } from '$lib/pathTracingShaders/ScreenOutput_Fragment.glsl?raw';
	import { default as scenePathTracingShader } from './MultiSPF_Dynamic_Scene_Fragment.glsl?raw';
	import type { OrthographicCamera, PerspectiveCamera, Scene } from 'three';

	import { sharedState } from './state';
	import { useKeyboardControls } from 'svelte-kbc';
	import type { Mesh } from 'three';
	import { Object3D } from 'three';

	const { w, a, s, d, shift, space } = useKeyboardControls();

	const { sceneInitiated, pathTracingScene, screenCopyScene, screenOutputScene } = sharedState;

	initPathTracingCommons();

	let SCREEN_WIDTH;
	let SCREEN_HEIGHT;
	let context;
	let controls;

	let pathTracingUniforms = {};
	let screenCopyUniforms, screenOutputUniforms;
	let pathTracingDefines;
	let demoFragmentShaderFileName;
	let pathTracingMesh: Mesh;
	let pathTracingRenderTarget, screenCopyRenderTarget;

	let quadCamera: OrthographicCamera;
	let worldCamera: PerspectiveCamera;

	let clock;
	let frameTime, elapsedTime;
	let sceneIsDynamic = false;
	let cameraFlightSpeed = 60;
	let cameraRotationSpeed = 1;
	let fovScale;

	let apertureSize = 0.0;
	let focusDistance = 132.0;
	let pixelRatio = 0.5;
	let TWO_PI = Math.PI * 2;
	let sampleCounter = 0.0; // will get increased by 1 in animation loop before rendering
	let frameCounter = 1.0; // 1 instead of 0 because it is used as a rng() seed in pathtracing shader
	let cameraIsMoving = false;
	let cameraRecentlyMoving = false;
	let isPaused = true;
	let oldYawRotation, oldPitchRotation;

	let EPS_intersect;
	let blueNoiseTexture;
	let useToneMapping = true;
	let allowOrthographicCamera = true;
	let pixelEdgeSharpness = 1.0;
	let edgeSharpenSpeed = 0.05;
	let filterDecaySpeed = 0.0002;

	let ableToEngagePointerLock = true;
	let orthographicCamera_ToggleController, orthographicCamera_ToggleObject;

	// the following variables will be used to calculate rotations and directions from the camera
	let cameraDirectionVector = new THREE.Vector3(); //for moving where the camera is looking
	let cameraRightVector = new THREE.Vector3(); //for strafing the camera right and left
	let cameraUpVector = new THREE.Vector3(); //for moving camera up and down
	let cameraWorldQuaternion = new THREE.Quaternion(); //for rotating scene objects to match camera's current rotation
	let cameraControlsObject; //for positioning and moving the camera itself
	let cameraControlsYawObject; //allows access to control camera's left/right movements through mobile input
	let cameraControlsPitchObject; //allows access to control camera's up/down movements through mobile input

	let PI_2 = Math.PI / 2; //used by controls below

	let mouseControl = true;
	let pointerlockChange;

	const setupControls = (camera: PerspectiveCamera) => {
		//
		camera.rotation.set(0, 0, 0);
	};

	const FirstPersonCameraControls = function (camera) {
		camera.rotation.set(0, 0, 0);
		var pitchObject = new Object3D();
		pitchObject.add(camera);
		var yawObject = new Object3D();
		yawObject.add(pitchObject);
		var movementX = 0;
		var movementY = 0;
		var onMouseMove = function (event) {
			if (isPaused) return;
			movementX = event.movementX || event.mozMovementX || 0;
			movementY = event.movementY || event.mozMovementY || 0;
			yawObject.rotation.y -= movementX * 0.0012 * cameraRotationSpeed;
			pitchObject.rotation.x -= movementY * 0.001 * cameraRotationSpeed;
			// clamp the camera's vertical movement (around the x-axis) to the scene's 'ceiling' and 'floor'
			pitchObject.rotation.x = Math.max(-PI_2, Math.min(PI_2, pitchObject.rotation.x));
		};
		document.addEventListener('mousemove', onMouseMove, false);
		this.getObject = function () {
			return yawObject;
		};
		this.getYawObject = function () {
			return yawObject;
		};
		this.getPitchObject = function () {
			return pitchObject;
		};
		this.getDirection = (function () {
			var te = pitchObject.matrixWorld.elements;
			return function (v) {
				v.set(te[8], te[9], te[10]).negate();
				return v;
			};
		})();
		this.getUpVector = (function () {
			var te = pitchObject.matrixWorld.elements;
			return function (v) {
				v.set(te[4], te[5], te[6]);
				return v;
			};
		})();
		this.getRightVector = (function () {
			var te = pitchObject.matrixWorld.elements;
			return function (v) {
				v.set(te[0], te[1], te[2]);
				return v;
			};
		})();
	};

	function onMouseWheel(event) {
		if (isPaused) return;

		// use the following instead, because event.preventDefault() gives errors in console
		event.stopPropagation();
	}

	function onWindowResize(event) {
		// the following change to document.body.clientWidth and Height works better for mobile, especially iOS
		// suggestion from Github user q750831855  - Thank you!
		SCREEN_WIDTH = window.innerWidth;
		SCREEN_HEIGHT = window.innerHeight;

		renderer.setPixelRatio(pixelRatio);
		renderer.setSize(SCREEN_WIDTH, SCREEN_HEIGHT);

		pathTracingUniforms.uResolution.value.x = context.drawingBufferWidth;
		pathTracingUniforms.uResolution.value.y = context.drawingBufferHeight;

		pathTracingRenderTarget.setSize(context.drawingBufferWidth, context.drawingBufferHeight);
		screenCopyRenderTarget.setSize(context.drawingBufferWidth, context.drawingBufferHeight);

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

	const { renderer } = useThrelte();

	function init() {
		if (mouseControl) {
			window.addEventListener('wheel', onMouseWheel, false);
			window.addEventListener(
				'dblclick',
				function (event) {
					event.preventDefault();
				},
				false
			);

			document.body.addEventListener(
				'click',
				function (event) {
					if (!ableToEngagePointerLock) return;
					this.requestPointerLock = this.requestPointerLock || this.mozRequestPointerLock;
					this.requestPointerLock();
				},
				false
			);

			pointerlockChange = function (event) {
				if (
					document.pointerLockElement === document.body ||
					document.mozPointerLockElement === document.body ||
					document.webkitPointerLockElement === document.body
				) {
					isPaused = false;
				} else {
					isPaused = true;
				}
			};

			// Hook pointer lock state change events
			document.addEventListener('pointerlockchange', pointerlockChange, false);
			document.addEventListener('mozpointerlockchange', pointerlockChange, false);
			document.addEventListener('webkitpointerlockchange', pointerlockChange, false);
		} // end if (mouseControl)

		initTHREEjs(); // boilerplate: init necessary three.js items and scene/demo-specific objects
		window.addEventListener('resize', onWindowResize, false);
	} // end function init()

	function initTHREEjs() {
		renderer.debug.checkShaderErrors = true;
		renderer.autoClear = false;
		renderer.toneMapping = THREE.ReinhardToneMapping;
		context = renderer.getContext();
		context.getExtension('EXT_color_buffer_float');

		clock = new THREE.Clock();

		// quadCamera is simply the camera to help render the full screen quad (2 triangles),
		// hence the name.  It is an Orthographic camera that sits facing the view plane, which serves as
		// the window into our 3d world. This camera will not move or rotate for the duration of the app.

		// worldCamera is the dynamic camera 3d object that will be positioned, oriented and
		// constantly updated inside the 3d scene.  Its view will ultimately get passed back to the
		// stationary quadCamera, which renders the scene to a fullscreen quad (made up of 2 large triangles).

		controls = new FirstPersonCameraControls(worldCamera);

		setupControls(worldCamera);

		cameraControlsObject = controls.getObject();
		cameraControlsYawObject = controls.getYawObject();
		cameraControlsPitchObject = controls.getPitchObject();

		$pathTracingScene?.add(cameraControlsObject);

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

		// check user controls
		if (mouseControl) {
			// movement detected
			if (
				oldYawRotation != cameraControlsYawObject.rotation.y ||
				oldPitchRotation != cameraControlsPitchObject.rotation.x
			) {
				cameraIsMoving = true;
			}

			// save state for next frame
			oldYawRotation = cameraControlsYawObject.rotation.y;
			oldPitchRotation = cameraControlsPitchObject.rotation.x;
		} // end if (mouseControl)

		// this gives us a vector in the direction that the camera is pointing,
		// which will be useful for moving the camera 'forward' and shooting projectiles in that direction
		controls.getDirection(cameraDirectionVector);
		cameraDirectionVector.normalize();
		controls.getUpVector(cameraUpVector);
		cameraUpVector.normalize();
		controls.getRightVector(cameraRightVector);
		cameraRightVector.normalize();

		// the following gives us a rotation quaternion (4D vector), which will be useful for
		// rotating scene objects to match the camera's rotation
		worldCamera.getWorldQuaternion(cameraWorldQuaternion);

		if ($w) {
			cameraControlsObject.position.add(
				cameraDirectionVector.multiplyScalar(cameraFlightSpeed * frameTime)
			);
			cameraIsMoving = true;
		}
		if ($s) {
			cameraControlsObject.position.sub(
				cameraDirectionVector.multiplyScalar(cameraFlightSpeed * frameTime)
			);
			cameraIsMoving = true;
		}
		if ($a) {
			cameraControlsObject.position.sub(
				cameraRightVector.multiplyScalar(cameraFlightSpeed * frameTime)
			);
			cameraIsMoving = true;
		}
		if ($d) {
			cameraControlsObject.position.add(
				cameraRightVector.multiplyScalar(cameraFlightSpeed * frameTime)
			);
			cameraIsMoving = true;
		}

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
		cameraControlsObject.updateMatrixWorld(true);
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
		renderer.setRenderTarget(null);
		renderer.render($screenOutputScene, quadCamera);
	} // end function animate()

	// scene/demo-specific variables go here
	let torusObject;
	let torusRotationAngle = 0;

	// called automatically from within initTHREEjs() function (located in InitCommon.js file)
	function initSceneData() {
		demoFragmentShaderFileName = 'MultiSPF_Dynamic_Scene_Fragment.glsl';

		// scene/demo-specific three.js objects setup goes here
		sceneIsDynamic = true;

		cameraFlightSpeed = 60;

		// pixelRatio is resolution - range: 0.5(half resolution) to 1.0(full resolution)
		pixelRatio = 0.75;

		EPS_intersect = 0.1;

		// Torus Object
		torusObject = new THREE.Object3D();
		$pathTracingScene?.add(torusObject);

		torusObject.position.set(-60, 18, 50);
		torusObject.scale.set(11.5, 11.5, 11.5);

		// set camera's field of view
		worldCamera.fov = 60;
		focusDistance = 130.0;

		// position and orient camera
		cameraControlsObject.position.set(0, 20, 120);
		// scene/demo-specific uniforms go here
		pathTracingUniforms.uTorusInvMatrix = { value: new THREE.Matrix4() };
		pathTracingUniforms.uSamplesPerFrame = { value: 12 };
		pathTracingUniforms.uPreviousFrameBlendWeight = { value: 0.7 };
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
	<T.Mesh>
		<T.ShaderMaterial
			uniforms={screenOutputUniforms}
			vertexShader={commonPathTracingVertex}
			fragmentShader={ScreenOutput_Fragment}
			depthTest={false}
			depthWrite={false}
		/>
		<T.PlaneGeometry args={[window.innerWidth, window.innerHeight]} />
	</T.Mesh>
</T.Scene>

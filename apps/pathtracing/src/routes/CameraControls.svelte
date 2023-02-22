<script lang="ts">
	import { requestPointerLockWithUnadjustedMovement } from '$lib/pointerLock';
	import { clamp } from '$lib/util';
	import { useFrame, useThrelte } from '@threlte/core';
	import { useKeyboardControls } from 'svelte-kbc';
	import { Euler } from 'three';
	import { Quaternion } from 'three';
	import { Vector3 } from 'three';
	import { sharedState } from '$lib/state';

	const {
		sceneInitiated,
		pathTracingScene,
		screenCopyScene,
		screenOutputScene,
		sceneCamera,
		outputCamera
	} = sharedState;

	const { renderer } = useThrelte();

	const { w, a, s, d, shift, space } = useKeyboardControls();

	const cameraRotation = new Euler();
	let phi = 0;
	let theta = 0;
	const mouseMove = {
		x: 0,
		y: 0
	};
	const mouseSensitivity = 0.002;

	window.addEventListener('mousemove', (e) => {
		mouseMove.x += e.movementX;
		mouseMove.y += e.movementY;
	});

	renderer?.domElement.addEventListener('click', async () => {
		requestPointerLockWithUnadjustedMovement(renderer?.domElement);
		// renderer?.domElement.requestPointerLock();
	});

	useFrame(() => {
		if (!$sceneCamera) return;
		phi += mouseMove.x * mouseSensitivity;
		theta = clamp(theta - mouseMove.y * mouseSensitivity, -Math.PI / 3, Math.PI / 3);
		const qx = new Quaternion();
		qx.setFromAxisAngle(new Vector3(0, -1, 0), phi);

		const qz = new Quaternion();
		qz.setFromAxisAngle(new Vector3(1, 0, 0), theta);

		const q = new Quaternion();
		q.multiply(qx);
		q.multiply(qz);

		mouseMove.x = 0;
		mouseMove.y = 0;

		$sceneCamera.quaternion.copy(q);

		if ($w || $a || $s || $d) {
			cameraRotation.setFromQuaternion($sceneCamera.quaternion);

			let speed = 3;

			let strafe = 0;
			let forward = 0;
			let upward = 0;

			if ($shift) {
				speed = 3;
			} else speed = 1;

			if ($w) {
				forward -= 1;
				upward += 1;
			}
			if ($s) {
				forward += 1;
				upward -= 1;
			}

			if ($a) {
				strafe -= 1;
			}

			if ($d) {
				strafe += 1;
			}

			const direction = new Vector3(strafe, 0, forward);

			direction.applyEuler(cameraRotation);
			direction.normalize();

			const translation = direction.multiply(new Vector3(speed, speed, speed));

			$sceneCamera.position.add(translation);
		}
	});
</script>

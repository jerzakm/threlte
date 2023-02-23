<script lang="ts">
	import { injectPathTracingPlugin } from '$lib/pathTracingPlugin';
	import { ptMaterials } from '$lib/pathTracingTypes';
	import { T, useFrame } from '@threlte/core';
	import { AutoColliders, RigidBody } from '@threlte/rapier';
	import { Color } from 'three';
	import { DEG2RAD } from 'three/src/math/MathUtils';

	injectPathTracingPlugin();

	let time = 0;

	useFrame(({ clock }) => {
		time = clock.elapsedTime;
	});
</script>

<RigidBody position={[-2.5, 80, 2.5]} rotation={[45 * DEG2RAD, 0, 45 * DEG2RAD]}>
	<AutoColliders shape={'convexHull'}>
		<T.Mesh ptDynamic ptMaterial={ptMaterials.COAT}>
			<T.BoxGeometry args={[20, 20, 20]} />
			<T.MeshBasicMaterial color="red" wireframe transparent opacity={0} />
		</T.Mesh>
	</AutoColliders>
</RigidBody>

{#each { length: 10 } as b, x}
	{@const angle = (360 / (x + 1)) * DEG2RAD}
	<RigidBody position={[Math.cos(angle) * 20, 10 + x * 5, Math.sin(angle) * 20]}>
		<AutoColliders shape={'convexHull'}>
			<T.Mesh ptDynamic ptMaterial={ptMaterials.COAT}>
				<T.BoxGeometry args={[8, 8, 8]} />
				<T.MeshBasicMaterial
					color={new Color(Math.random(), Math.random(), Math.random())}
					wireframe
					transparent
					opacity={0}
				/>
			</T.Mesh>
		</AutoColliders>
	</RigidBody>
{/each}

<AutoColliders>
	<T.Mesh ptDynamic ptMaterial={ptMaterials.DIFF}>
		<T.BoxGeometry args={[500, 1, 500]} />
		<T.MeshBasicMaterial color="white" wireframe transparent opacity={0} />
	</T.Mesh>
</AutoColliders>

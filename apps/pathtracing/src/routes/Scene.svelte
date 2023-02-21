<script lang="ts">
	import { OrbitControls, T } from '@threlte/core';
	import { Grid } from '@threlte/extras';
	import { DoubleSide } from 'three';
</script>

<Grid sectionThickness={0} />

<T.PerspectiveCamera makeDefault position={[5, 5, 5]}>
	<OrbitControls enabled />
</T.PerspectiveCamera>

<!-- <T.Mesh material={tMat}>
	<T.BoxGeometry args={[3, 3, 3]} />
</T.Mesh> -->

<T.Mesh position.x={3}>
	<T.BoxGeometry />
	<T.MeshStandardMaterial color={'red'} side={DoubleSide} />
</T.Mesh>

<T.DirectionalLight intensity={2} />
<T.AmbientLight intensity={2} />

<T.Mesh>
	<T.SphereGeometry args={[100]} />
	<T.MeshBasicMaterial color={'#666666'} side={DoubleSide} />
</T.Mesh>

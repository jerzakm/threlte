<script lang="ts">
	import { injectPathTracingPlugin } from '$lib/pathTracingPlugin';
	import { T } from '@threlte/core';

	injectPathTracingPlugin();
</script>

<T.Mesh ptDynamic>
	<T.BoxGeometry args={[20, 20, 20]} />
	<T.MeshBasicMaterial color="red" wireframe transparent opacity={0} />
</T.Mesh>

<T.Mesh ptDynamic position.x={50}>
	<T.BoxGeometry args={[20, 20, 20]} />
	<T.MeshBasicMaterial color="yellow" wireframe transparent opacity={0} />
</T.Mesh>

<T.Mesh ptDynamic position.z={-20} position.x={10}>
	<T.BoxGeometry args={[20, 20, 20]} />
	<T.MeshBasicMaterial color="green" wireframe transparent opacity={0} />
</T.Mesh>

<T.Mesh ptDynamic position.y={-1}>
	<T.BoxGeometry args={[200, 1, 200]} />
	<T.MeshBasicMaterial color="white" wireframe transparent opacity={0} />
</T.Mesh>

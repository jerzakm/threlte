<script lang="ts">
	import { injectPathTracingPlugin } from '$lib/pathTracingPlugin';
	import { T } from '@threlte/core';

	injectPathTracingPlugin();
</script>

<T.Mesh render>
	<T.BoxGeometry args={[20, 20, 20]} />
	<T.MeshBasicMaterial color="yellow" wireframe transparent opacity={0} />
</T.Mesh>

<T.Mesh render position.x={50}>
	<T.BoxGeometry args={[20, 20, 20]} />
	<T.MeshBasicMaterial color="yellow" wireframe transparent opacity={0} />
</T.Mesh>

<T.Mesh render position.y={-1}>
	<T.BoxGeometry args={[200, 1, 200]} />
	<T.MeshBasicMaterial color="white" wireframe transparent opacity={0} />
</T.Mesh>

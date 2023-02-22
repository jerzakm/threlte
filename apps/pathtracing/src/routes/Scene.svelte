<script lang="ts">
	import { injectPathTracingPlugin } from '$lib/pathTracingPlugin';
	import { T } from '@threlte/core';

	injectPathTracingPlugin();
</script>

<T.Mesh render>
	<T.BoxGeometry args={[20, 20, 20]} />
	<T.MeshBasicMaterial color="yellow" wireframe />
</T.Mesh>

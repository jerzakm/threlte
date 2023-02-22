<script lang="ts">
	import { Canvas } from '@threlte/core';
	import { KeyboardControls, wasdConfig } from 'svelte-kbc';
	import PathTracingCore from './PathTracingCore.svelte';
	import Postprocessing from './Postprocessing.svelte';
	import Scene from './Scene.svelte';
</script>

<KeyboardControls config={wasdConfig()}>
	<Canvas
		frameloop={'always'}
		rendererParameters={{
			powerPreference: 'high-performance',
			antialias: false,
			stencil: false,
			depth: false
		}}
	>
		<PathTracingCore>
			<Scene />
		</PathTracingCore>
		<Postprocessing />
	</Canvas>
</KeyboardControls>

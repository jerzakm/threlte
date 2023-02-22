<script lang="ts">
	import { Canvas, useFrame, useThrelte } from '@threlte/core';
	import { KeyboardControls, wasdConfig } from 'svelte-kbc';
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
		<Scene />
		<Postprocessing />
	</Canvas>
</KeyboardControls>

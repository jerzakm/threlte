<script lang="ts">
	import { sharedState } from '$lib/state';
	import { Canvas } from '@threlte/core';
	import { Debug, World } from '@threlte/rapier';
	import { KeyboardControls, wasdConfig } from 'svelte-kbc';
	import CameraControls from './CameraControls.svelte';
	import PathTracingCore from './PathTracingCore.svelte';
	import Postprocessing from './Postprocessing.svelte';
	import Scene from './Scene.svelte';

	const { debug } = sharedState;
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
		flat
		linear
	>
		<CameraControls />

		<World>
			<PathTracingCore>
				<Scene />
				{#if $debug}
					<Debug />
				{/if}
			</PathTracingCore>
		</World>
		<Postprocessing />
	</Canvas>
</KeyboardControls>

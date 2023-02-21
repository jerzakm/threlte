<script lang="ts">
	import { Canvas, useFrame, useThrelte } from '@threlte/core';
	import Scene from './Scene.svelte';
</script>

<Canvas frameloop={'always'}>
	<Scene />
</Canvas>

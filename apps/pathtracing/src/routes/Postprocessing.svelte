<script lang="ts">
	import { useThrelte } from '@threlte/core';
	import {
		BloomEffect,
		ChromaticAberrationEffect,
		EffectComposer,
		EffectPass,
		KernelSize,
		RenderPass
	} from 'postprocessing';
	import { onDestroy } from 'svelte';
	import { Vector2 } from 'three';
	import { sharedState } from './state';

	const ctx = useThrelte();

	const { arcadeMachineScene } = gameState;
	const { camera, renderer } = ctx;

	let bloomEffect: BloomEffect | undefined = undefined;

	$: if (bloomEffect) bloomEffect.intensity = 1;

	const composer = new EffectComposer(renderer);
	ctx.composer = composer as any;

	const addComposerAndPasses = () => {
		composer.removeAllPasses();

		bloomEffect = new BloomEffect({
			intensity: 1,
			luminanceThreshold: 0.15,
			height: 512,
			width: 512,
			luminanceSmoothing: 0.08,
			mipmapBlur: true,
			kernelSize: KernelSize.MEDIUM
		});
		bloomEffect.luminancePass.enabled = true;
		(bloomEffect as any).ignoreBackground = true;
		composer.addPass(new RenderPass($arcadeMachineScene, $camera));
		composer.addPass(
			new EffectPass(
				$camera,
				new ChromaticAberrationEffect({
					offset: new Vector2(0.0, 0.0),
					modulationOffset: 0,
					radialModulation: false
				})
			)
		);
	};

	$: if (renderer && $camera && $arcadeMachineScene) {
		addComposerAndPasses();
	}
	onDestroy(() => {
		composer.removeAllPasses();
	});
</script>

<script lang="ts">
	import { useThrelte } from '@threlte/core';
	import {
		BloomEffect,
		ChromaticAberrationEffect,
		EffectComposer,
		EffectPass,
		GaussianBlurPass,
		KernelSize,
		RenderPass,
		SMAAEffect,
		SMAAPreset
	} from 'postprocessing';
	import { onDestroy } from 'svelte';
	import { Vector2 } from 'three';
	import { sharedState } from './state';

	const ctx = useThrelte();

	const { outputCamera, screenOutputScene } = sharedState;
	const { camera, renderer } = ctx;

	let bloomEffect: BloomEffect | undefined = undefined;

	$: if (bloomEffect) bloomEffect.intensity = 1;

	const composer = new EffectComposer(renderer);
	ctx.composer = composer as any;

	const addComposerAndPasses = () => {
		composer.removeAllPasses();

		bloomEffect = new BloomEffect({
			intensity: 8,
			luminanceThreshold: 0.75,
			height: 512,
			width: 512,
			luminanceSmoothing: 0.08,
			mipmapBlur: true,
			kernelSize: KernelSize.MEDIUM
		});
		bloomEffect.luminancePass.enabled = true;
		// (bloomEffect as any).ignoreBackground = true;

		composer.addPass(new RenderPass($screenOutputScene, $outputCamera));
		composer.addPass(new RenderPass($screenOutputScene, $outputCamera));

		composer.addPass(new EffectPass($camera, bloomEffect));
		// composer.addPass(
		// 	new GaussianBlurPass({
		// 		iterations: 3,
		// 		kernelSize: 8,
		// 		resolutionScale: 1,
		// 		resolutionX: window.innerWidth,
		// 		resolutionY: window.innerHeight
		// 	})
		// );
		composer.addPass(
			new EffectPass(
				$camera,
				new ChromaticAberrationEffect({
					offset: new Vector2(0.001, 0.001),
					modulationOffset: 0,
					radialModulation: false
				})
			)
		);
	};

	$: if (renderer && $camera && $screenOutputScene) {
		console.log('adding passes');
		addComposerAndPasses();
	}
	onDestroy(() => {
		composer.removeAllPasses();
	});
</script>

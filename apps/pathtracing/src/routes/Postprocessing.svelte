<script lang="ts">
	import { useThrelte } from '@threlte/core';
	import {
		BlendFunction,
		BloomEffect,
		Effect,
		EffectComposer,
		EffectPass,
		FXAAEffect,
		KernelSize,
		PixelationEffect,
		RenderPass
	} from 'postprocessing';
	import { onDestroy } from 'svelte';
	import { sharedState } from '$lib/state';
	import { Uniform } from 'three';
	import { Vector3 } from 'three';
	import { default as denoiseFrag } from './_denoise2.frag?raw';
	import { default as doggyFrag } from './_doggy.frag?raw';

	const ctx = useThrelte();

	const { outputCamera, screenOutputScene } = sharedState;
	const { camera, renderer } = ctx;

	let bloomEffect: BloomEffect | undefined = undefined;

	$: if (bloomEffect) bloomEffect.intensity = 1;

	const composer = new EffectComposer(renderer);
	ctx.composer = composer as any;

	const addComposerAndPasses = () => {
		composer.removeAllPasses();

		const blur = new Effect('denoiseEffect', denoiseFrag, {
			blendFunction: BlendFunction.NORMAL,
			uniforms: new Map([['weights', new Uniform(new Vector3(1, 0, 0))]])
		});

		const doggy = new Effect('doggyEffect', doggyFrag, {
			blendFunction: BlendFunction.NORMAL,
			uniforms: new Map([['weights', new Uniform(new Vector3(1, 0, 0))]])
		});

		const fxaa = new FXAAEffect({
			blendFunction: BlendFunction.NORMAL
		});

		const pixelate = new PixelationEffect(1);

		bloomEffect = new BloomEffect({
			intensity: 4,
			luminanceThreshold: 0.85,
			height: 256,
			width: 256,
			luminanceSmoothing: 0.01,
			mipmapBlur: true,
			kernelSize: KernelSize.VERY_SMALL
		});
		// bloomEffect.luminancePass.enabled = true;

		composer.addPass(new RenderPass($screenOutputScene, $outputCamera));
		composer.addPass(new RenderPass($screenOutputScene, $outputCamera));

		composer.addPass(new EffectPass($camera, bloomEffect));
		composer.addPass(new EffectPass($camera, fxaa, blur));
		// composer.addPass(new EffectPass($camera, doggy));
	};

	$: if (renderer && $camera && $screenOutputScene) {
		console.log('adding passes');
		addComposerAndPasses();
	}
	onDestroy(() => {
		composer.removeAllPasses();
	});
</script>

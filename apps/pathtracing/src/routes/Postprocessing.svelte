<script lang="ts">
	import { useThrelte } from '@threlte/core';
	import {
		BlendFunction,
		BloomEffect,
		Effect,
		EffectComposer,
		EffectPass,
		KernelSize,
		RenderPass
	} from 'postprocessing';
	import { onDestroy } from 'svelte';
	import { sharedState } from '$lib/state';
	import { Uniform } from 'three';
	import { Vector3 } from 'three';
	import { default as denoiseFrag } from './_denoise1.frag?raw';
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

		bloomEffect = new BloomEffect({
			intensity: 8,
			luminanceThreshold: 0.75,
			height: 1024,
			width: 1024,
			luminanceSmoothing: 0.01,
			mipmapBlur: true,
			kernelSize: KernelSize.MEDIUM
		});
		bloomEffect.luminancePass.enabled = true;

		// const denoiseEffect = new DenoiseEffect();

		composer.addPass(new RenderPass($screenOutputScene, $outputCamera));
		composer.addPass(new RenderPass($screenOutputScene, $outputCamera));

		// composer.addPass(new EffectPass($camera, doggy));
		// composer.addPass(new EffectPass($camera, blur));
		// composer.addPass(new EffectPass($camera, blur));
	};

	$: if (renderer && $camera && $screenOutputScene) {
		console.log('adding passes');
		addComposerAndPasses();
	}
	onDestroy(() => {
		composer.removeAllPasses();
	});
</script>

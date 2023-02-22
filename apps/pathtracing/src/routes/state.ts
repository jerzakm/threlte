import { writable } from 'svelte/store';
import type { Scene } from 'three';

const sceneInitiated = writable(false);
const pathTracingScene = writable<Scene | undefined>(undefined);
const screenCopyScene = writable<Scene | undefined>(undefined);
const screenOutputScene = writable<Scene | undefined>(undefined);

export const sharedState = {
	sceneInitiated,
	pathTracingScene,
	screenCopyScene,
	screenOutputScene
};

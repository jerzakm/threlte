import { writable } from 'svelte/store';
import type { OrthographicCamera, PerspectiveCamera, Scene } from 'three';

const sceneInitiated = writable(false);
const pathTracingScene = writable<Scene | undefined>(undefined);
const screenCopyScene = writable<Scene | undefined>(undefined);
const screenOutputScene = writable<Scene | undefined>(undefined);
const sceneCamera = writable<PerspectiveCamera | undefined>(undefined);
const outputCamera = writable<OrthographicCamera | undefined>(undefined);

export const sharedState = {
	sceneInitiated,
	pathTracingScene,
	screenCopyScene,
	screenOutputScene,
	sceneCamera,
	outputCamera
};

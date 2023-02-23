import { writable } from 'svelte/store';
import type { OrthographicCamera, PerspectiveCamera, Scene } from 'three';
import type { PathTracingBox } from './pathTracingTypes';

const sceneInitiated = writable(false);
const debug = writable(false);
const pathTracingScene = writable<Scene | undefined>(undefined);
const screenCopyScene = writable<Scene | undefined>(undefined);
const screenOutputScene = writable<Scene | undefined>(undefined);
const sceneCamera = writable<PerspectiveCamera | undefined>(undefined);
const outputCamera = writable<OrthographicCamera | undefined>(undefined);
const pathTracingBoxes = writable<{ [key: string]: PathTracingBox }>({});

export const sharedState = {
	sceneInitiated,
	pathTracingScene,
	screenCopyScene,
	screenOutputScene,
	sceneCamera,
	outputCamera,
	debug
};

export const pathTracingState = {
	pathTracingBoxes
};

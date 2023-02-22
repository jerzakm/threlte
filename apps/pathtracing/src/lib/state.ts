import { writable } from 'svelte/store';
import type { OrthographicCamera, PerspectiveCamera, Scene } from 'three';

type v3 = {
	x: number;
	y: number;
	z: number;
};

interface PathTracingBox {
	minCorner: v3;
	maxCorner: v3;
	color: v3;
	emission: v3;
	type: number;
}

const sceneInitiated = writable(false);
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
	outputCamera
};

export const pathTracingState = {
	pathTracingBoxes
};

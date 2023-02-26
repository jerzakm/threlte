import { writable, type Writable } from 'svelte/store';
import type { OrthographicCamera, PerspectiveCamera, Scene } from 'three';
import type { PathTracingBox } from './pathTracingTypes';

const sceneInitiated = writable(false);
const debug = writable(false);

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
	outputCamera,
	debug
};

const pathTracingBoxes = writable<{ [key: string]: PathTracingBox }>({});
const cameraIsMoving = writable(false);
const pixelRatio = writable(1);
const samplesPerFrame = writable(2);
const blendWeight = writable(0.5);
const epsIntersect = writable(0.1);
const rendererSize: Writable<[width: number, height: number]> = writable([300, 300]);

export const pathTracingState = {
	pathTracingBoxes,
	cameraIsMoving,
	pixelRatio,
	samplesPerFrame,
	blendWeight,
	epsIntersect,
	rendererSize
};

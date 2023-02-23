import { injectPlugin, useFrame, useThrelte } from '@threlte/core';
import { onDestroy, onMount } from 'svelte';
import { get } from 'svelte/store';
import { BoxGeometry, Matrix4, Mesh, MeshStandardMaterial, Object3D } from 'three';
import type { PathTracingBox, v3 } from './pathTracingTypes';
import { pathTracingState } from './state';

const getMaterial = (material: MeshStandardMaterial) => {
	const { r, g, b } = material.color || { r: 0, g: 0, b: 0 };
	return { type: 1, color: [r, g, b] satisfies v3 };
};

const setBox = (id: string, ref: any) => {
	const box = getPathTracingBox(ref);
	pathTracingState.pathTracingBoxes.update((state) => ({ ...state, [id]: box }));
};

const getPathTracingBox = (mesh: Mesh) => {
	mesh.updateMatrixWorld();
	const geometry: BoxGeometry = mesh.geometry;

	const { type, color } = getMaterial(mesh.material);

	const invMatrix = new Matrix4();
	invMatrix.copy(mesh.matrixWorld).invert();

	const box: PathTracingBox = {
		emission: [0, 0, 0],
		minCorner: [
			-geometry.parameters.width / 2,
			-geometry.parameters.height / 2,
			-geometry.parameters.depth / 2
		],
		maxCorner: [
			geometry.parameters.width / 2,
			geometry.parameters.height / 2,
			geometry.parameters.depth / 2
		],
		type,
		invMatrix: invMatrix.toArray(),
		color
	};

	return box;
};

export const injectPathTracingPlugin = () => {
	injectPlugin('pathTracing', ({ ref, props }) => {
		// skip injection if ref is not an Object3D
		if (!(ref instanceof Object3D) || !('ptDynamic' in props)) return;
		// get the invalidate function from the useThrelte hook
		const { invalidate } = useThrelte();

		const { pathTracingBoxes } = pathTracingState;

		// create some variables to store the current ref and props
		let currentRef = ref;
		let currentProps = props;
		// create a temp vector to avoid creating new vectors on every iteration
		// const applyProps = (p: typeof props, r: typeof ref) => {
		// 	if (!('pathTracing' in p)) return;
		// 	const prop = p.lookAt;
		// 	if (prop instanceof Vector3) tempV3.copy(prop);
		// 	if (Array.isArray(prop) && prop.length === 3) {
		// 		tempV3.set(prop[0], prop[1], prop[2]);
		// 	} else if (typeof prop === 'object') {
		// 		tempV3.set(prop.x ?? 0, prop.y ?? 0, prop.z ?? 0);
		// 	}
		// 	r.lookAt(tempV3);
		// 	invalidate();
		// };
		// applyProps(currentProps, currentRef);

		let type: 'box' | 'sphere' = 'box';
		const id = `${ref.id}`;

		useFrame(() => {
			if (type == 'box') {
				setBox(id, ref);
			}
		});

		onMount(() => {
			if (ref.type == 'Mesh') {
				if (ref.geometry.type == 'BoxGeometry') {
					type = 'box';
					setBox(id, ref);
				}
			}
			//
		});

		onDestroy(() => {
			const n = get(pathTracingBoxes);
			delete n[id];

			pathTracingBoxes.set(n);
		});

		return {
			onRefChange(ref) {
				currentRef = ref;

				if (type == 'box') {
					//
				}

				// applyProps(currentProps, currentRef);
			},
			onPropsChange(props) {
				currentProps = props;
				// applyProps(currentProps, currentRef);
			},
			pluginProps: ['ptDynamic', 'ptMaterial']
		};
	});
};

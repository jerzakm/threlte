export type v3 = [x: number, y: number, z: number];

export interface PathTracingBox {
	minCorner: v3;
	maxCorner: v3;
	color: v3;
	emission: v3;
	type: number;
	invMatrix: number[];
}

export const materialTypes = {
	SPOT_LIGHT: -2,
	POINT_LIGHT: -1,
	LIGHT: 0,
	DIFF: 1,
	REFR: 2,
	SPEC: 3,
	COAT: 4,
	CARCOAT: 5,
	TRANSLUCENT: 6,
	SPECSUB: 7,
	CHECK: 8,
	WATER: 9,
	PBR_MATERIAL: 10,
	WOOD: 11,
	SEAFLOOR: 12,
	TERRAIN: 13,
	CLOTH: 14,
	LIGHTWOOD: 15,
	DARKWOOD: 16,
	PAINTING: 17,
	METALCOAT: 18
};

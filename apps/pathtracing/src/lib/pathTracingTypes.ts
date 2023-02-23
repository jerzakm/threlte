export type v3 = [x: number, y: number, z: number];

export interface PathTracingBox {
	minCorner: v3;
	maxCorner: v3;
	color: v3;
	emission: v3;
	type: number;
}

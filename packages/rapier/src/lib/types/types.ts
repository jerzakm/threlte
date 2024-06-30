import {
  World,
  type Collider,
  type ColliderHandle,
  type RigidBody,
  type RigidBodyHandle,
  type TempContactManifold,
  type Vector
} from '@dimforge/rapier3d-compat'
import type { Writable, Readable } from 'svelte/store'
import type { createRapierContext } from '../lib/createRapierContext'
import type { Object3D, Object3DEventMap } from 'three'
import type { CurrentWritable } from '@threlte/core'

export type ColliderShapes =
  | 'ball'
  | 'capsule'
  | 'segment'
  | 'triangle'
  | 'roundTriangle'
  | 'polyline'
  | 'trimesh'
  | 'cuboid'
  | 'roundCuboid'
  | 'heightfield'
  | 'cylinder'
  | 'roundCylinder'
  | 'cone'
  | 'roundCone'
  | 'convexHull'
  | 'convexMesh'
  | 'roundConvexHull'
  | 'roundConvexMesh'

export type AutoCollidersShapes = 'cuboid' | 'ball' | 'trimesh' | 'convexHull' | 'capsule'

export type ColliderEvents = {
  oncreate?: (event: { ref: Collider; cleanup: (callback: () => void) => void }) => void
  oncollisionenter?: (event: {
    targetCollider: Collider
    targetRigidBody: RigidBody | null
    manifold: TempContactManifold
    flipped: boolean
  }) => void
  oncollisionexit?: (event: { targetCollider: Collider; targetRigidBody: RigidBody | null }) => void
  onsensorenter?: (event: { targetCollider: Collider; targetRigidBody: RigidBody | null }) => void
  onsensorexit?: (event: { targetCollider: Collider; targetRigidBody: RigidBody | null }) => void
  oncontact?: (event: {
    targetCollider: Collider
    targetRigidBody: RigidBody | null
    maxForceDirection: Vector
    maxForceMagnitude: number
    totalForce: Vector
    totalForceMagnitude: number
  }) => void
}

export type CollisionEnterEvent = ColliderEvents['oncollisionenter']
export type CollisionExitEvent = ColliderEvents['oncollisionexit']
export type SensorEnterEvent = ColliderEvents['onsensorenter']
export type SensorExitEvent = ColliderEvents['onsensorexit']
export type ContactEvent = ColliderEvents['oncontact']

export type RigidBodyEvents = ColliderEvents & {
  onsleep?: () => void
  onwake?: () => void
}

export type CollisionGroupsContext = Writable<number> | undefined

export type RigidBodyUserData = {
  events?: RigidBodyEvents
}

export type ThrelteRigidBody = RigidBody & {
  userData?: RigidBodyUserData
}

export type RigidBodyContext = ThrelteRigidBody

export type CollisionGroupsBitMask = (
  | 0
  | 1
  | 2
  | 3
  | 4
  | 5
  | 6
  | 7
  | 8
  | 9
  | 10
  | 11
  | 12
  | 13
  | 14
  | 15
)[]

/**
 * Used in the <Attractor> component
 */
export type GravityType = 'static' | 'linear' | 'newtonian'

export type Framerate = number | 'varying'

export type RapierContext = {
  rapier: typeof import('/Users/grischaerbe/Projects/threlte/node_modules/.pnpm/@dimforge+rapier3d-compat@0.12.0/node_modules/@dimforge/rapier3d-compat/exports')
  world: World
  colliderObjects: Map<number, Object3D>
  rigidBodyObjects: Map<number, Object3D>
  rigidBodyEventDispatchers: Map<number, RigidBodyEvents>
  colliderEventDispatchers: Map<number, ColliderEvents>
  addColliderToContext: (collider: Collider, object: Object3D, props: ColliderEvents) => void
  removeColliderFromContext: (collider: Collider) => void
  addRigidBodyToContext: (rigidBody: RigidBody, object: Object3D, events: RigidBodyEvents) => void
  removeRigidBodyFromContext: (rigidBody: RigidBody) => void
  debug: Writable<boolean>
  pause: () => void
  resume: () => void
  paused: Readable<boolean>
  framerate: CurrentWritable<Framerate>
  /**
   * This number tells us how far we're off in the simulation stage as opposed
   * to the render stage
   */
  simulationOffset: number
}

<!--
Auto-generated by: https://github.com/threlte/threlte/tree/main/packages/gltf
Command: npx @threlte/gltf@2.0.1 scope.glb
Author: XarMeX (https://sketchfab.com/XarMeX)
License: CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
Source: https://sketchfab.com/3d-models/sniper-scope-nightforce-v2-907abe0a96e243b3b83b6abe47f681b7
Title: Sniper Scope NightForce_V2
-->

<script lang="ts">
  import * as THREE from 'three'

  import { T, type Props, type Events, type Slots, forwardEventHandlers } from '@threlte/core'
  import { useGltf } from '@threlte/extras'
  import { tweened, type Tweened } from 'svelte/motion'
  import { scoping } from '../Controls.svelte'
  import { DEG2RAD } from 'three/src/math/MathUtils.js'

  type $$Props = Props<THREE.Group>
  type $$Events = Events<THREE.Group>
  type $$Slots = Slots<THREE.Group> & { fallback: {}; error: { error: any }; inner: any }

  export const ref = new THREE.Group()

  const gltf = useGltf('/models/scope.glb')

  const component = forwardEventHandlers()

  const rotationX = tweened(-3)
  const position: Tweened<THREE.Vector3Tuple> = tweened([0.4, -0.15, -1])

  $: {
    if ($scoping) {
      rotationX.set(0)
      position.set([0, 0, -0.496])
    } else {
      rotationX.set(-3)
      position.set([0.4, -0.15, -1])
    }
  }
</script>

<T
  is={ref}
  dispose={false}
  {...$$restProps}
  bind:this={$component}
  scale={0.02}
  position={$position}
  rotation.y={DEG2RAD * $rotationX}
>
  {#await gltf}
    <slot name="fallback" />
  {:then gltf}
    <T.Mesh
      geometry={gltf.nodes.Object_2.geometry}
      material={gltf.materials.initialShadingGroup}
      rotation={[-Math.PI / 2, 0, 0]}
    />
    <slot name="inner" />
  {:catch error}
    <slot
      name="error"
      {error}
    />
  {/await}

  <slot {ref} />
</T>

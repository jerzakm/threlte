<script lang="ts">
  import { forwardEventHandlers } from '@threlte/core'
  import type { ComponentEvents, ComponentProps } from 'svelte'
  import { loadYoga, type Yoga } from 'yoga-layout'
  import InnerRoot from './InnerRoot.svelte'
  import type { NodeProps } from '$lib/lib/props'

  type $$Props = Omit<ComponentProps<InnerRoot>, 'yoga'> & {
    classParser?: (classes: string) => NodeProps
  }
  type $$Events = ComponentEvents<InnerRoot>

  export let classParser: $$Props['classParser'] = undefined

  let yoga: Yoga | undefined

  const initialize = async () => {
    yoga = await loadYoga()
  }

  initialize()

  const component = forwardEventHandlers()
</script>

{#if yoga}
  <InnerRoot
    {yoga}
    {classParser}
    {...$$restProps}
    bind:this={$component}
    let:reflow
  >
    <slot {reflow} />
  </InnerRoot>
{/if}

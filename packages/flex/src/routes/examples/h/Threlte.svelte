<script lang="ts">
  import { T } from '@threlte/core'
  import Root from '../../../lib/Root/Root.svelte'
  import Item from '../../../lib/nodes/Item/Item.svelte'
  import Plane from '../../Plane.svelte'
  import Test from '../../Test.svelte'
  import Common from '../Common.svelte'
  import Container from '../../../lib/nodes/Container/Container.svelte'
  import Gizmo from '../../Gizmo.svelte'
  import type { NodeProps } from '$lib/lib/props'

  const classParser = (classes: string) => {
    console.log(`parsing - ${classes}`)
    //some cool logic here
    const styles: NodeProps = {}
    if (classes === 'p-20') {
      styles.padding = 20
    }
    return styles
  }
</script>

<Common />

<Plane
  width={500}
  height={500}
  color="red"
/>

<Root
  width={500}
  height={500}
  justifyContent="Center"
  alignItems="Stretch"
  gap={20}
  padding={20}
  {classParser}
>
  <Item
    width="auto"
    height="auto"
    flex={1}
    let:width
    let:height
  >
    <Plane
      color="yellow"
      {width}
      {height}
    />
  </Item>

  <Item
    width="auto"
    height="auto"
    flex={0.5}
    alignItems="Stretch"
    cls={'p-20'}
    let:width
    let:height
  >
    <Plane
      color="blue"
      {width}
      {height}
    />

    <Item
      flex={1}
      width="auto"
      height={100}
      let:width
      let:height
    >
      <Plane
        color="pink"
        {width}
        {height}
      />
    </Item>

    <Item
      flex={1}
      width="auto"
      height={100}
      alignSelf="FlexEnd"
      let:width
      let:height
    >
      <Plane
        color="hotpink"
        {width}
        {height}
      />
    </Item>
  </Item>
</Root>

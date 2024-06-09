import { useThrelte } from '@threlte/core'
import { Mesh } from 'three'
import { MaskThreeObject } from '../../masks/mask-types/MaskThreeObject.svelte'
import { TourStop } from '../TourStop.svelte'
import { InstructionsBasic } from '../../instructions/InstructionsBasic'
import { useTransformControls } from '@threlte/studio/extensions'

export class TransformControlsTourStop extends TourStop {
  constructor() {
    const { scene } = useThrelte()
    const torus = scene.getObjectByName('Torus')
    if (!torus) throw new Error('Torus not found')
    if (!(torus instanceof Mesh)) throw new Error('Torus is not a Mesh')
    const mask = new MaskThreeObject(torus, 'circle', 0, true, false, false)
    const instructions = new InstructionsBasic(
      'Use the transform controls to transform the object. To rotate the Torus object, press R on your keyboard.'
    )
    super(mask, instructions)

    const tc = useTransformControls()

    $effect(() => {
      if (!this.isActive) return
      if (tc.mode === 'rotate') {
        this.stopCompleted()
      }
    })
  }
}

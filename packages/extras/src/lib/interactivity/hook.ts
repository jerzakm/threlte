import { createRawEventDispatcher } from '@threlte/core'
import type { Object3D } from 'three'
import { getHandlerContext, getInteractivityContext } from './context'

export const useInteractivity = () => {
  const context = getInteractivityContext()
  const { dispatchers } = getHandlerContext()

  if (!context) {
    throw new Error('No interactivity context found. Did you forget to implement interactivity()?')
  }

  const eventDispatcher = createRawEventDispatcher()

  const addInteractiveObject = (object: Object3D) => {
    // check if the object is already in the list
    if (context.interactiveObjects.indexOf(object) > -1) {
      return
    }

    dispatchers.set(object, eventDispatcher)
    context.interactiveObjects.push(object)
  }

  const removeInteractiveObject = (object: Object3D) => {
    const index = context.interactiveObjects.indexOf(object)
    context.interactiveObjects.splice(index, 1)
    dispatchers.delete(object)
  }

  return {
    ...context,
    addInteractiveObject,
    removeInteractiveObject
  }
}

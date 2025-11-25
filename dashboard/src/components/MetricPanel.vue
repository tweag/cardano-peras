<script setup lang="ts">
import { defineProps, computed } from 'vue'
import D3Plot, { Axis, Curve, Legend } from './D3Plot.vue'
import PlotControls, { PlotControlProps } from './PlotControls.vue'

export interface MetricProps {
  title: string
  description: string
  axes: { x: Axis; y: Axis }
  legend?: Legend
  globals: Record<string, PlotControlProps>
  controls: Record<string, PlotControlProps>
  compute: (param: Record<string, number>) => Curve[]
}

const props = defineProps<MetricProps>()

// Compute curves data based on global and metric-specific control values
const curves = computed(() => {
  const allControls = { ...props.globals, ...props.controls }
  const controlValues = Object.fromEntries(
    Object.entries(allControls).map(([key, control]) => [key, control.value])
  )
  return props.compute(controlValues)
})
</script>

<template>
  <article class="container">
    <details closed>
      <summary>
        <b>{{ title }}</b>
      </summary>
      <p>{{ description }}</p>
      <D3Plot :axes="axes" :legend="legend" :curves="curves"> </D3Plot>
      <PlotControls :controls="controls" />
    </details>
  </article>
</template>

<style scoped>
details {
  margin-bottom: 0em;
}
summary {
  margin-left: 1em;
  margin-right: 1em;
}
p {
  margin: 1em;
}
</style>

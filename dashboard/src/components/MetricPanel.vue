<script setup lang="ts">
import { defineProps, computed } from 'vue'
import D3Plot, { Curve } from './D3Plot.vue'
import PlotControls, { PlotControlProps } from './PlotControls.vue'

export interface MetricProps {
  title: string
  description: string
  labels: { x: string; y: string }
  globals: Record<string, PlotControlProps>
  controls: Record<string, PlotControlProps>
  logScale?: { x?: boolean; y?: boolean }
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
      <D3Plot :labels="labels" :curves="curves" :log-scale="logScale"> </D3Plot>
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

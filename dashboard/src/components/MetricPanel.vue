<script setup lang="ts">
import { defineProps, computed } from 'vue'
import D3Plot, { Axis } from './D3Plot.vue'
import PlotControls from './PlotControls.vue'

const props = defineProps<{
  title: string
  description: string
  labels: { x: string; y: string }
  controls: Record<string, number>
  compute:(controls: Record<string, number>) => Axis[]
}>()

// Compute axes data based on control values
const axes = computed(() => {
  const controlValues = Object.fromEntries(
    Object.entries(props.controls)
      .map(([key, control]) => [key, control.value])
  )
  return props.compute(controlValues)
})
</script>

<template>
  <article class="container">
    <details closed>
      <summary><b>{{ title }}</b></summary>
      <p>{{ description }}</p>
      <D3Plot
        :labels="labels"
        :axes="axes"
        >
      </D3Plot>
      <PlotControls
        :controls="controls"
      />
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

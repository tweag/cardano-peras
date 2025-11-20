<script setup lang="ts">
import { defineProps } from 'vue'
import PlotControls, { PlotControl } from './PlotControls.vue'

defineProps<{
  controls: Record<string, PlotControl>
}>()
</script>

<template>
  <article class="container">
    <details closed>
      <summary><b>Global parameters</b></summary>
      <p>Lorem ipsum ...</p>
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

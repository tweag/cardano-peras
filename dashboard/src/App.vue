<script setup lang="ts">
import { defineProps, reactive } from 'vue'
import { PlotControlProps } from './components/PlotControls.vue'
import MetricPanel, { MetricProps } from './components/MetricPanel.vue'
import GlobalControls from './components/GlobalControls.vue'

const props = defineProps<{
  title: string
  footer?: string
  globals: Record<string, PlotControlProps>
  metrics: MetricProps[]
}>()

const globalControls = reactive(props.globals)
</script>

<template>
  <header class="container-fluid">
    <h1>{{ title }}</h1>
  </header>
  <main>
    <GlobalControls :controls="globalControls" />
    <MetricPanel
      v-for="(metric, index) in metrics"
      :key="index"
      :title="metric.title"
      :description="metric.description"
      :labels="metric.labels"
      :globals="globalControls"
      :controls="reactive(metric.controls)"
      :compute="metric.compute"
    />
  </main>
  <footer v-if="footer" class="container-fluid">
    {{ footer }}
  </footer>
</template>

<style scoped>
header {
  text-align: center;
  margin-top: 2em;
  margin-bottom: 2em;
}
footer {
  text-align: center;
  margin-top: 2em;
}
</style>

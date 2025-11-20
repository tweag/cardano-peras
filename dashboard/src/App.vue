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
  <div class="container-fluid wrapper">
    <nav>
      <ul>
        <li>
          <strong>{{ title }}</strong>
        </li>
      </ul>
      <ul>
        <li><a href="#">Link 1</a></li>
        <li><a href="#">Link 2</a></li>
      </ul>
    </nav>
    <main class="content">
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
  </div>
</template>

<style scoped>
.wrapper {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}
nav {
  margin-bottom: 2em;
}
header {
  text-align: center;
  margin-top: 2em;
  margin-bottom: 2em;
}
main {
  flex: 1;
}
footer {
  text-align: center;
  margin-top: 2em;
  padding-bottom: 1em;
}
</style>

<script setup lang="ts">
import SampleMetric1 from './components/SampleMetric1.vue'
import SampleMetric2 from './components/SampleMetric2.vue'
</script>

<template>
  <header class="container-fluid">
    <h1>Peras Dashboard</h1>
  </header>
  <main>
    <SampleMetric1 />
    <SampleMetric2 />
  </main>
  <footer class="container-fluid">
    Footer content
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

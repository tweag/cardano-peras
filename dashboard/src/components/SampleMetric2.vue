<script setup lang="ts">
import { reactive } from 'vue'
import MetricPanel from './MetricPanel.vue'
</script>

<template>
  <MetricPanel
    title="Metric #2"
    description="This metric also showcases that and this."
    :labels="{
      x: 'Bazs per day',
      y: 'Quxes per baz'
    }"
    :controls="reactive({
      foo: { type: 'slider', value: 10, min: 10, max: 100, step: 1 },
      bar: { type: 'selector', value: 1, min: 1, max: 5, step: 1 }
    })"
    :compute="(ctrl) => [
      {
        label: 'sin(x / (bar + foo)) * (x / bar)',
        data: Array.from({ length: 1000 }, (_, x) => ({
          x: x,
          y: Math.sin(x / (ctrl.bar + ctrl.foo)) * (x / ctrl.bar)
        }))
      },
      {
        label: 'cos(x / foo) * foo * bar',
        data: Array.from({ length: 1000 }, (_, x) => ({
          x: x,
          y: Math.cos(x / ctrl.foo) * ctrl.foo * ctrl.bar
        }))
      }
    ]"
  />
</template>

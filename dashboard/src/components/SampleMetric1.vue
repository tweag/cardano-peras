<script setup lang="ts">
import { reactive } from 'vue'
import MetricPanel from './MetricPanel.vue'
</script>

<template>
  <MetricPanel
    title="Metric #1"
    description="This metric showcases this and that."
    :labels="{
      x: 'Bars per minute',
      y: 'Foos per bar'
    }"
    :controls="reactive({
      baz: { type: 'slider', value: 0, min: 0, max: 10, step: 1 }
    })"
    :compute="(ctrl) => [
      {
        label: 'Line 1',
        data: [
          { x: 10, y: 20 + ctrl.baz },
          { x: 30, y: 40 - ctrl.baz },
          { x: 50, y: 25 + ctrl.baz },
          { x: 70, y: 60 - ctrl.baz },
          { x: 90, y: 80 + ctrl.baz }
        ]
      },
      {
        label: 'Line 2',
        data: [
          { x: 5 , y: 30 - ctrl.baz },
          { x: 25, y: 45 + ctrl.baz },
          { x: 45, y: 25 - ctrl.baz },
          { x: 65, y: 65 + ctrl.baz },
          { x: 85, y: 85 - ctrl.baz }
        ]
      }
    ]"
  />
</template>

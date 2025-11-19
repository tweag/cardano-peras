<script setup lang="ts">
import { defineProps } from 'vue'

export interface PlotControl {
  type: 'slider' | 'selector'
  value: number
  min?: number
  max?: number
  step?: number
}

defineProps<{
  controls: Record<string, PlotControl>
}>()
</script>

<template>
  <div class="plot-controls grid">
    <div
      v-for="(control, name) in controls"
      :key="name"
      class="control-item"
    >
      <!-- Control label -->
      <label :for="name">
        {{ `${name}: ${control.value}` }}
      </label>
      <!-- Slider control -->
      <input
        v-if="control.type === 'slider'"
        type="range"
        v-model.number="control.value"
        :id="name"
        :min="control.min"
        :max="control.max"
        :step="control.step"
      />
      <!-- Selector control -->
      <select
        v-else-if="control.type === 'selector'"
        v-model.number="control.value"
        :id="name"
      >
        <option
          v-for="
            option in
            Array.from(
              {length: control.max - control.min + 1},
              (_, i) => ({
                value: control.min + i,
                label: (control.min + i).toString()
              })
            )
          "
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
    </div>
  </div>
</template>

<style scoped>
.plot-controls {
  margin: 2em;
}
.control-item {
  margin: 1em 1em 1em 1em;
}
</style>

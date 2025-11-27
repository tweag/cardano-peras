<script setup lang="ts">
import { defineProps } from 'vue'

export interface PlotControlProps {
  name?: string
  type: 'slider' | 'selector' | 'spinner'
  value: number
  min?: number
  max?: number
  step?: number
  tooltip?: string
}

defineProps<{
  controls: Record<string, PlotControlProps>
}>()
</script>

<template>
  <div class="plot-controls grid">
    <div v-for="(control, name) in controls" :key="name" class="control-item">
      <!-- Control label -->
      <label
        :for="name"
        :class="[control.tooltip ? 'tooltip' : '']"
        :title="control.tooltip || ''"
      >
        {{ control.tooltip ? 'ⓘ' : '' }}
        {{
          (control.name ? control.name : name) +
          // Show current value for controls that normally don't display it
          (control.type == 'slider' ? `: ${control.value}` : '')
        }}
      </label>
      <!-- Slider control -->
      <input
        v-if="control.type === 'slider'"
        :id="name"
        v-model.number="control.value"
        type="range"
        :min="control.min"
        :max="control.max"
        :step="control.step"
      />
      <!-- Selector control -->
      <select
        v-else-if="control.type === 'selector'"
        :id="name"
        v-model.number="control.value"
      >
        <option
          v-for="option in Array.from(
            { length: control.max - control.min + 1 },
            (_, i) => ({
              value: control.min + i,
              label: (control.min + i).toString(),
            })
          )"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
      <!-- Spinner control -->
      <input
        v-else-if="control.type === 'spinner'"
        :id="name"
        v-model.number="control.value"
        type="number"
        :min="control.min"
        :max="control.max"
        :step="control.step"
      />
    </div>
  </div>
</template>

<style scoped>
.plot-controls {
  margin-top: 0em;
  margin-bottom: 0em;
  margin-left: 2em;
  margin-right: 2em;
  display: grid;
  grid-template-columns: repeat(3, auto);
}
.control-item {
  margin: 1em 1em 1em 1em;
}
.tooltip {
  position: relative;
  cursor: help;
}
</style>

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
  compute?: (params: Record<string, number>) => number
}

defineProps<{
  controls: Record<string, PlotControlProps>
}>()

function autoCompute(controls: Record<string, PlotControlProps>): void {
  const params = Object.keys(controls).reduce((acc, key) => {
    acc[key] = controls[key].value
    return acc
  }, {} as Record<string, number>)
  Object.entries(controls).forEach(([name, control]) => {
    const checkbox = document.getElementById(
      'checkbox-' + name
    ) as HTMLInputElement
    const inputField = document.getElementById(
      'input-' + name
    ) as HTMLInputElement
    if (control.compute && checkbox.checked) {
      control.value = control.compute(params)
    }
    if (checkbox) {
      inputField.disabled = checkbox.checked
    }
  })
}
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
        :id="'input-' + name"
        v-model.number="control.value"
        type="range"
        :min="control.min"
        :max="control.max"
        :step="control.step"
        :disabled="control.compute !== undefined"
        @change="autoCompute(controls)"
      />
      <!-- Selector control -->
      <select
        v-else-if="control.type === 'selector'"
        :id="'input-' + name"
        v-model.number="control.value"
        :disabled="control.compute !== undefined"
        @change="autoCompute(controls)"
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
        :id="'input-' + name"
        v-model.number="control.value"
        type="number"
        :min="control.min"
        :max="control.max"
        :step="control.step"
        :disabled="control.compute !== undefined"
        @change="autoCompute(controls)"
      />
      <!-- Enable derivation of parameter from other parameters -->
      <div v-if="control.compute">
        <input
          :id="'checkbox-' + name"
          type="checkbox"
          checked
          @change="autoCompute(controls)"
        />
        <label for="name">Derive from other parameters</label>
      </div>
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

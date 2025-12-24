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
    const button = document.getElementById('lock-' + name) as HTMLButtonElement
    const inputField = document.getElementById(
      'input-' + name
    ) as HTMLInputElement
    const isLocked = button && button.dataset.locked === 'true'
    if (control.compute && isLocked) {
      control.value = control.compute(params)
    }
    if (button) {
      inputField.disabled = isLocked
    }
  })
}

function toggleLock(
  name: string,
  controls: Record<string, PlotControlProps>
): void {
  const button = document.getElementById('lock-' + name) as HTMLButtonElement
  const isLocked = button.dataset.locked === 'true'
  const newLockedState = !isLocked
  button.dataset.locked = newLockedState.toString()
  button.textContent = newLockedState ? '🔗' : '⛓️‍💥'
  autoCompute(controls)
}
</script>

<template>
  <div class="plot-controls">
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

      <!-- Control -->
      <div :class="control.compute ? 'control-with-lock' : ''">
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

        <!-- Enable auto derivation of parameter from other parameters -->
        <button
          v-if="control.compute"
          class="tooltip lock-button secondary"
          :id="'lock-' + name"
          data-locked="true"
          :title="'Auto-derive this parameter from the rest.'"
          @click="toggleLock(name as string, controls)"
        >
          🔗
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.plot-controls {
  margin-top: 0em;
}
.tooltip {
  position: relative;
  cursor: help;
}
.control-with-lock {
  display: grid;
  grid-template-columns: 1fr auto;
}
.lock-button {
  padding: 0.2em 0.5em;
  height: 3em;
  cursor: pointer;
}
.lock-button:hover {
  opacity: 0.8;
}
</style>

<script lang="ts">
import { defineComponent } from 'vue'
import UnderConstruction from './components/UnderConstruction.vue'

export default defineComponent({
  name: 'App',
  components: {
    UnderConstruction
  }
})
</script>

<template>
  <UnderConstruction title="Peras Dashboard" />
</template>

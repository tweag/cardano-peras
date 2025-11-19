<script lang="ts">
import { defineProps } from 'vue'

defineProps<{
  title: string
}>()
</script>

<template>
  <main id="under-construction" class="container-fluid">
    <img
      id="logo"
      alt="Tweag logo"
      width="50%"
      src="../assets/tweag_logo.svg"
    />
    <h1>{{ title }}</h1>
    <p><i>This website is currently under construction.</i></p>
  </main>
</template>

<style scoped>
#under-construction {
  text-align: center;
  margin-top: 100px;
}
#logo {
  margin-top: 50px;
  margin-bottom: 50px;
}
</style>

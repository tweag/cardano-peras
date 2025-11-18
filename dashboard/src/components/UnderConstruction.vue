<script lang="ts">
import { defineComponent } from 'vue'

export default defineComponent({
  name: 'UnderConstruction',
  props: {
    title: String
  }
})
</script>

<template>
  <main class="container-fluid" id="under-construction">
    <img id="logo" alt="Tweag logo" width="50%" src="../assets/tweag_logo.svg">
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

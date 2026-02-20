<script setup lang="ts">
import { defineProps, reactive } from 'vue'
import PlotControls, { PlotControlProps } from './components/PlotControls.vue'
import MetricPanel, { MetricProps } from './components/MetricPanel.vue'

const props = defineProps<{
  title?: string
  footer?: string
  globals: Record<string, PlotControlProps>
  metrics: MetricProps[]
}>()

const globalControls = reactive(props.globals)
</script>

<template>
  <div class="container-fluid wrapper">
    <header v-if="title" class="container-fluid">
      <h2>{{ title }}</h2>
    </header>
    <div class="content">
      <aside>
        <h4>Global Parameters</h4>
        <PlotControls :controls="globalControls" />
      </aside>
      <main>
        <h4>Overview</h4>
        <article>
          <details open>
            <summary>What is Peras?</summary>
            <p>
              Peras, or more precisely Ouroboros Peras, is an extension of
              Ouroboros Praos that addresses one of the known issues of
              blockchains based on Nakamoto-style consensus, namely settlement
              time. Peras achieves that goal while being self-healing,
              preserving the security of Praos, and being light on resources.
            </p>
          </details>
          <details open>
            <summary>About this dashboard</summary>
            <p>
              The global parameters to the left apply to all metrics below. In
              addition, each metric may have its own specific parameters that
              you can adjust. Use the controls to see how the metrics change in
              real-time.
            </p>
          </details>
          <details open>
            <summary>Resources</summary>
            <ul>
              <li>
                <a
                  href="https://github.com/cardano-foundation/CIPs/blob/master/CIP-0140/README.md"
                >
                  Peras CIP (CIP-0140)
                </a>
              </li>
              <li>
                <a
                  href="https://peras.cardano-scaling.org/dashboard/index.html"
                >
                  Original Peras dashboard
                </a>
              </li>
              <li>
                <a href="https://eprint.iacr.org/2022/1571.pdf">
                  Practical Settlement Bounds for Longest-Chain Consensus
                </a>
              </li>
              <li>
                <a href="https://github.com/renling/LCanalysis">
                  Numeric evaluation of longest-chain PoW and PoS blockchains
                </a>
              </li>
              <li>
                <a
                  href="https://tweag.github.io/cardano-peras/peras-design.pdf"
                >
                  Peras design document
                </a>
              </li>
            </ul>
          </details>
        </article>

        <h4>Metrics</h4>
        <MetricPanel
          v-for="(metric, index) in metrics"
          :key="index"
          :title="metric.title"
          :description="metric.description"
          :axes="metric.axes"
          :legend="metric.legend"
          :globals="globalControls"
          :controls="reactive(metric.controls)"
          :compute="metric.compute"
          :open="index === 0"
        />
      </main>
    </div>
    <footer v-if="footer" class="container-fluid">
      {{ footer }}
    </footer>
  </div>
</template>

<style scoped>
nav {
  margin-bottom: 2em;
}
header {
  text-align: center;
  margin-top: 2em;
  margin-bottom: 2em;
}
main {
  flex: 1;
}
details {
  margin-bottom: 0.5em;
  margin-top: 0.5em;
}
aside {
  flex: 0 0 340px;
  min-width: 340px;
  position: sticky;
  top: 1em;
  align-self: flex-start;
}
footer {
  text-align: center;
  margin-top: 2em;
  padding-bottom: 1em;
}
h4 {
  margin-bottom: 1em;
}
.wrapper {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}
.content {
  display: flex;
  flex: 1;
  gap: 2em;
  margin-top: 1em;
}
</style>

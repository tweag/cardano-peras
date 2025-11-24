import './assets/css/style.css'

import { createApp } from 'vue'
import App from './App.vue'
import Rollback from './metrics/Rollback'

createApp(App, {
  title: 'Peras Dashboard',
  footer: '© 2024 Peras Inc.',
  globals: {
    U: {
      type: 'slider',
      value: 90,
      min: 1,
      max: 180,
      step: 1,
      name: 'Round length',
      tooltip: 'in slots',
    },
    // B: {
    //   type: 'slider',
    //   value: 15,
    //   min: 1,
    //   max: 30,
    //   step: 1,
    //   name: 'Boost',
    //   tooltip: 'in blocks',
    // },
    L: {
      type: 'slider',
      value: 30,
      min: 1,
      max: 100,
      step: 1,
      name: 'Block selection offset',
      tooltip: 'in slots',
    },
    f: {
      type: 'slider',
      value: 0.05,
      min: 0,
      max: 1,
      step: 0.01,
      name: 'Active slot coefficient',
      tooltip: 'in 1/slots',
    },
  },
  metrics: [Rollback],
}).mount('#app')

// Global parameters:
// 'Certificate expiration (A, in slots)'
// 'Chain ignorance (R, in rounds)'
// 'Cooldown period (K, in rounds)'
// 'Block selection offset (L, in slots)'
// 'Mean committee size (n, in nodes)'
// 'Quorum size (τ / n, in %/100)'
// 'Active slot coefficient (f, in 1/slot)'
// 'Security parameter (k, in blocks)'

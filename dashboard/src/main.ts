import './assets/css/style.css'

import { createApp } from 'vue'
import App from './App.vue'
import FooBar from './metrics/FooBar'
import Spring from './metrics/Spring'

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
      tooltip: 'Number of slots in a Peras round',
    },
  },
  metrics: [FooBar, Spring],
}).mount('#app')

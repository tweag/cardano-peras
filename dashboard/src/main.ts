import './assets/css/style.css'

import { createApp } from 'vue'
import App from './App.vue'
import Rollback from './metrics/Rollback'
import NoQuorum from './metrics/NoQuorum'
import Uptime from './metrics/Uptime'
import Spring from './metrics/Spring'
import FooBar from './metrics/FooBar'

createApp(App, {
  title: 'Peras Dashboard',
  footer: '© 2024 Peras Inc.',
  globals: {
    B: {
      type: 'spinner',
      value: 15,
      min: 1,
      max: 30,
      step: 1,
      name: 'B: Boost, in block weight',
      tooltip: 'The extra chain weight that a certificate gives to a block.',
    },
    U: {
      type: 'spinner',
      value: 90,
      min: 1,
      max: 180,
      step: 1,
      name: 'U: Round length, in slots',
      tooltip: 'The duration of each voting round.',
    },
    A: {
      type: 'spinner',
      value: 27000,
      min: 60,
      max: 86400,
      step: 1,
      name: 'A: Certificate expiration, in slots',
      tooltip: 'The maximum age for a certificate to be included in a block.',
      compute: (params: Record<string, number>) => {
        return (90 * params.B) / params.f
      },
    },
    R: {
      type: 'spinner',
      value: 300,
      min: 90,
      max: 1000,
      step: 1,
      name: 'R: Chain ignorance, in rounds',
      tooltip:
        'The number of rounds for which to ignore certificates after entering a cool-down period.',
      compute: (params: Record<string, number>) => {
        return Math.round(params.A / params.U)
      },
    },
    K: {
      type: 'spinner',
      value: 780,
      min: 90,
      max: 2000,
      step: 1,
      name: 'K: Cooldown period, in rounds',
      tooltip:
        'The minimum number of rounds to wait before voting again after a cool-down period starts.',
      compute: (params: Record<string, number>) => {
        return Math.round((2160 + 90 * params.B) / params.f / params.U)
      },
    },
    L: {
      type: 'spinner',
      value: 30,
      min: 1,
      max: 100,
      step: 1,
      name: 'L: Block selection offset, in slots',
      tooltip: 'The minimum age of a candidate block for being voted upon.',
    },
    n: {
      type: 'spinner',
      value: 900,
      min: 10,
      max: 2000,
      step: 10,
      name: 'n: Mean committee size, in nodes',
      tooltip: 'The number of members on the voting committee.',
    },
    quorum: {
      type: 'spinner',
      value: 0.75,
      min: 0.5,
      max: 1,
      step: 0.01,
      name: 'Quorum threshold',
      tooltip:
        'The percentage of votes, relative to the mean committee size, required to create a certificate.',
    },
    f: {
      type: 'spinner',
      value: 0.05,
      min: 0.01,
      max: 0.99,
      step: 0.01,
      name: 'f: Active slot coefficient, in blocks/slot',
      tooltip:
        'The probability that a party will be the slot leader for a particular slot.',
    },
    k: {
      type: 'spinner',
      value: 3510,
      min: 2160,
      max: 16384,
      step: 1,
      name: 'k: security parameter, in blocks',
      tooltip: 'The limit on the number of blocks to reach a common prefix.',
      compute: (params: Record<string, number>) => {
        return 2160 + 90 * params.B
      },
    },
  },
  metrics: [Rollback, NoQuorum, Uptime, Spring, FooBar],
}).mount('#app')

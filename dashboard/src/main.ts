import './assets/css/style.css'

import { createApp } from 'vue'
import App from './App.vue'
import Rollback from './metrics/Rollback'
import NoQuorum from './metrics/NoQuorum'
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
    // TODO: derive value from other parameters
    A: {
      type: 'spinner',
      value: 3600,
      min: 60,
      max: 86400,
      step: 1,
      name: 'A: Certificate expiration, in slots',
      tooltip: 'The maximum age for a certificate to be included in a block.',
    },
    // TODO: derive value from other parameters
    R: {
      type: 'spinner',
      value: 300,
      min: 300,
      max: 300,
      step: 1,
      name: 'R: Chain ignorance, in rounds',
      tooltip:
        'The number of rounds for which to ignore certificates after entering a cool-down period.',
    },
    // TODO: derive value from other parameters
    K: {
      type: 'spinner',
      value: 780,
      min: 780,
      max: 780,
      step: 1,
      name: 'K: Cooldown period, in rounds',
      tooltip:
        'The minimum number of rounds to wait before voting again after a cool-down period starts.',
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
      type: 'slider',
      value: 0.75,
      min: 0.5,
      max: 1,
      step: 0.01,
      name: 'Quorum size, in %/100',
      tooltip:
        'The percentage of votes, relative to the mean committee size, required to create a certificate.',
    },
    f: {
      type: 'spinner',
      value: 0.05,
      min: 0.01,
      max: 0.99,
      step: 0.01,
      name: 'f: Active slot coefficient, in 1/slots',
      tooltip:
        'The probability that a party will be the slot leader for a particular slot.',
    },
    // TODO: derive value from other parameters
    k: {
      type: 'spinner',
      value: 780,
      min: 780,
      max: 780,
      step: 1,
      name: 'k: security parameter, in blocks',
      tooltip: 'The limit on the number of blocks to reach a common prefix.',
    },
    slotDuration: {
      type: 'spinner',
      value: 1,
      min: 0.1,
      max: 60,
      step: 0.1,
      name: 'slot duration, in seconds per slot',
      tooltip: 'The duration of one cardano slot.',
    },
  },
  metrics: [Rollback, NoQuorum, Spring, FooBar],
}).mount('#app')

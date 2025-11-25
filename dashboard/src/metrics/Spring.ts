import { discretize, dampedOscillator } from '../metrics'

export default {
  title: 'Metric #2 (Damped Oscillator)',
  description: 'This metric also showcases that and this.',
  axes: {
    x: {
      label: 'Time (s)',
    },
    y: {
      label: 'Displacement (m)',
    },
  },
  controls: {
    gamma: {
      type: 'slider',
      value: 0,
      min: 0,
      max: 5,
      step: 0.1,
      tooltip: 'Damping coefficient',
    },
    omega: {
      type: 'slider',
      value: 1,
      min: 1,
      max: 5,
      step: 0.1,
      tooltip: 'Angular frequency',
    },
  },
  compute: (ctrl: Record<string, number>) => [
    {
      label: 'A=0.5',
      data: discretize((x) => dampedOscillator(0.5, ctrl.gamma, ctrl.omega, x)),
    },
    {
      label: 'A=1',
      data: discretize((x) => dampedOscillator(1, ctrl.gamma, ctrl.omega, x)),
    },
    {
      label: 'A=2',
      data: discretize((x) => dampedOscillator(2, ctrl.gamma, ctrl.omega, x)),
    },
  ],
}

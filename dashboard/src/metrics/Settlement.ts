import { discretize, pPerasRollback, pPraosRollback } from '../metrics'

export default {
  title: 'Rollback probability (PLACEHOLDER)',
  description:
    'The probability that a block will be rolled back as time passes, with and without Peras',
  axes: {
    x: {
      label: 'Time in slots',
    },
    y: {
      label: 'Rollback probability',
      log: true,
      scientific: true,
    },
  },
  legend: {
    position: 'top-right',
  },
  controls: {
    advStake: {
      type: 'slider',
      value: 0.15,
      min: 0.01,
      max: 0.5,
      step: 0.01,
      name: 'Adversary stake fraction',
    },
  },
  compute: (ctrl: Record<string, number>) => {
    const minValue = 1
    const maxValue = 1800
    const steps = 1800

    return [
      {
        label: 'Peras rollback probability',
        data: discretize(
          (slot) => pPerasRollback(slot),
          minValue,
          maxValue,
          steps
        ),
      },
      {
        label: 'Praos rollback probability',
        data: discretize(
          (slot) => pPraosRollback(slot),
          minValue,
          maxValue,
          steps
        ),
      },
    ]
  },
}

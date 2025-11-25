import { discretize, pRollbackAfterOneBoost } from '../metrics'

export default {
  title: 'Probability of rollback after one boost',
  description: 'Compared to rollback probability after ',
  axes: {
    x: {
      label: 'Weight of Peras certificate',
    },
    y: {
      label: 'Rollback probability',
      log: true,
      scientific: true,
    },
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
    const minBoost = 1
    const maxBoost = 20
    const boostSteps = 20
    const advStakes = [0.01, 0.5, ctrl.advStake]

    return advStakes.map((stake) => ({
      label: `Adversarial stake = ${stake}`,
      data: discretize(
        (B) => pRollbackAfterOneBoost(stake, ctrl.f, ctrl.U, ctrl.L, B),
        minBoost,
        maxBoost,
        boostSteps
      ),
    }))
  },
}

import { discretize, pRollbackAfterOneBoost } from '../metrics'

export default {
  title: 'Probability of rollback after one boost',
  description: 'Compared to rollback probability after ',
  labels: {
    x: 'Weight of Peras certificate',
    y: 'Rollback probability',
  },
  logScale: { y: true },
  controls: {
    advStake: {
      type: 'slider',
      value: 0.15,
      min: 0,
      max: 0.5,
      step: 0.01,
      name: 'Adversary stake fraction',
    },
  },
  compute: (ctrl: Record<string, number>) => [
    {
      label: 'Adversarial stake = 0.01',
      data: discretize(
        (B) => {
          const y = pRollbackAfterOneBoost(0.01, ctrl.f, ctrl.U, ctrl.L, B)
          return y[0]
        },
        1,
        20,
        20
      ),
    },
    {
      label: 'Adversarial stake = 0.5',
      data: discretize(
        (B) => {
          const y = pRollbackAfterOneBoost(0.5, ctrl.f, ctrl.U, ctrl.L, B)
          return y[0]
        },
        1,
        20,
        20
      ),
    },
    {
      label: 'Custom adversarial stake',
      data: discretize(
        (B) => {
          const y = pRollbackAfterOneBoost(
            ctrl.advStake,
            ctrl.f,
            ctrl.U,
            ctrl.L,
            B
          )
          return y[0]
        },
        1,
        20,
        20
      ),
    },
    // {
    //   label: 'A=1',
    //   data: discretize((x) => dampedOscillator(1, 2, 3, x)),
    // },
    // {
    //   label: 'A=2',
    //   data: discretize((x) => dampedOscillator(2, ctrl.gamma, ctrl.omega, x)),
    // },
  ],
}

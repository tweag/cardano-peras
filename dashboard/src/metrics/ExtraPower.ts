import { discretize, extraPower } from '../metrics'

export default {
  title: 'Extra processing power',
  description:
    'This metric provides an upper bound on the extra processing power needed by Peras to issue and verify votes and certificates. It heavily depends on the number of peers of a given node.',
  axes: {
    x: {
      label: 'Neighborhood size',
    },
    y: {
      label: 'Extra bandwidth per node, in percentage',
    },
  },
  legend: {
    position: 'bottom-right',
  },
  controls: {},
  compute: (ctrl: Record<string, number>) => {
    const minValue = 1
    const maxValue = 100
    const steps = 100

    return [
      {
        label: 'Extra processing power',
        data: discretize(
          (neighborhood) =>
            extraPower(
              neighborhood,
              ctrl.voteGenerationTime,
              ctrl.voteVerificationTime,
              ctrl.certGenerationTime,
              ctrl.n,
              ctrl.U
            ),
          minValue,
          maxValue,
          steps
        ),
      },
    ]
  },
}

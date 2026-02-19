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
      label: 'Extra bandwidth per node, in CPU percentage',
    },
  },
  legend: {
    position: 'bottom-right',
  },
  controls: {
    voteGenerationTime: {
      type: 'spinner',
      value: 280,
      min: 10,
      max: 1_000_000,
      step: 1,
      name: 'Vote generation time (μs)',
      tooltip: "The time it takes to generate a vote with a node's private key",
    },
    voteVerificationTime: {
      type: 'spinner',
      value: 1400,
      min: 10,
      max: 1_000_000,
      step: 1,
      name: 'Vote verification time (μs)',
      tooltip:
        "The time it takes to check the authenticity of a vote, with it's issuer public key",
    },
    certGenerationTime: {
      type: 'spinner',
      value: 63000,
      min: 10,
      max: 1_000_000,
      step: 1,
      name: 'Certificate generation time (μs)',
      tooltip:
        'The time it takes to generate a certificate by aggregating votes',
    },
    // Certificate verification time is currently unused, because it only matters
    // when trying to sync in Genesis mode from a historical database, or when trying
    // to validate a certificate that has been included in a block.
    // Those are not behaviors of healthy, caught-up Peras nodes.
    // certVerificationTime: {
    //   type: 'spinner',
    //   value: 115000,
    //   min: 10,
    //   max: 1_000_000,
    //   step: 1,
    //   name: 'Certificate verification time (μs)',
    //   tooltip: 'The time it takes to check the authenticity of a certificate',
    // },
  },
  compute: (ctrl: Record<string, number>) => {
    const minValue = 1
    const maxValue = 100
    const steps = 100

    return [
      {
        label: 'Extra processing power (CPU %)',
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

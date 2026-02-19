import { discretize, extraTraffic } from '../metrics'

export default {
  title: 'Extra bandwidth',
  description:
    'This metric provides an upper bound on the extra bandwidth consumed by Peras by exchanging votes between nodes. It heavily depends on the number of peers of a given node.',
  axes: {
    x: {
      label: 'Neighborhood size',
    },
    y: {
      label: 'Extra bandwidth per node, in KiB/s',
    },
  },
  legend: {
    position: 'bottom-right',
  },
  controls: {
    voteSize: {
      type: 'spinner',
      value: 100,
      min: 8,
      max: 2 ^ 20,
      step: 1,
      name: 'Vote size (bytes)',
      tooltip: 'The size of a Peras vote, all cryptographic material included',
    },
    // Certificate size is currently unused, because it only matters when trying
    // to sync in Genesis mode from a historical database. This is not a behavior
    // of caught-up Peras nodes.
    // certSize: {
    //   type: 'spinner',
    //   value: 7000,
    //   min: 8,
    //   max: 2 ^ 20,
    //   step: 1,
    //   name: 'Certificate size (bytes)',
    //   tooltip:
    //     'The size of a Peras certificate, all cryptographic material included',
    // },
  },
  compute: (ctrl: Record<string, number>) => {
    const minValue = 1
    const maxValue = 100
    const steps = 100

    return [
      {
        label: 'Extra traffic (KiB/s)',
        data: discretize(
          (neighborhood) =>
            extraTraffic(neighborhood, ctrl.voteSize, ctrl.n, ctrl.U),
          minValue,
          maxValue,
          steps
        ),
      },
    ]
  },
}

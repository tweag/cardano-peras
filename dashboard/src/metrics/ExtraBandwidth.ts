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
  controls: {},
  compute: (ctrl: Record<string, number>) => {
    const minValue = 1
    const maxValue = 200
    const steps = 200

    return [
      {
        label: 'Extra traffic',
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

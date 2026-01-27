import { discretize, uptimePercentage } from '../metrics'

export default {
  title: 'Uptime percentage',
  description:
    'The percentage of time during which Peras will not be on cooldown, assuming the adversarial stake never casts a vote',
  axes: {
    x: {
      label: 'Adversarial stake',
    },
    y: {
      label: 'Uptime percentage of healthy Peras',
    },
  },
  legend: {
    position: 'top-right',
  },
  controls: {
    committee_size_overwrite: {
      type: 'slider',
      value: 500,
      min: 10,
      max: 2000,
      step: 10,
      name: 'Mean number of nodes in a voting committee',
    },
  },
  compute: (ctrl: Record<string, number>) => {
    const minValue = 0
    const maxValue = 0.5
    const steps = 1000
    const committees = [100, 1000, ctrl.committee_size_overwrite]

    return committees.map((n) => ({
      label: `Committee size = ${n}`,
      data: discretize(
        (advStake) =>
          uptimePercentage(ctrl.k, ctrl.f, ctrl.K, ctrl.quorum, n, advStake),
        minValue,
        maxValue,
        steps
      ),
    }))
  },
}

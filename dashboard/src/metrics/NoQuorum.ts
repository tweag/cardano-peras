import { discretize, pNoHonestQuorum } from '../metrics'

export default {
  title: 'Probability of a round not reaching quorum',
  description:
    'The probability that honest parties will not have sufficient votes to reach a quorum in a given voting round',
  axes: {
    x: {
      label: 'Adversarial stake',
    },
    y: {
      label: 'Probability of reaching no quorum',
    },
  },
  legend: {
    position: 'bottom-right',
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
        (advStake) => pNoHonestQuorum(ctrl.quorum, n, advStake),
        minValue,
        maxValue,
        steps
      ),
    }))
  },
}

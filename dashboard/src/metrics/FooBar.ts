export default {
  title: 'Metric #1 (The mythical foo-bar correlation)',
  description: 'This metric showcases this and that.',
  labels: {
    x: 'Bars',
    y: 'Foos per bar',
  },
  controls: {
    baz: {
      type: 'slider',
      value: 0,
      min: 0,
      max: 10,
      step: 0.1,
      name: 'Baz factor',
      tooltip: 'Inverse logarithmic correlation factor',
    },
  },
  compute: (ctrl: Record<string, number>) => [
    {
      label: 'Monday',
      data: [
        { x: 10, y: 20 + ctrl.baz + ctrl.U / 10 },
        { x: 30, y: 40 - ctrl.baz + ctrl.U / 10 },
        { x: 50, y: 25 + ctrl.baz + ctrl.U / 10 },
        { x: 70, y: 60 - ctrl.baz + ctrl.U / 10 },
        { x: 90, y: 80 + ctrl.baz + ctrl.U / 10 },
      ],
    },
    {
      label: 'Tuesday',
      data: [
        { x: 5, y: 30 - ctrl.baz },
        { x: 25, y: 45 + ctrl.baz },
        { x: 45, y: 25 - ctrl.baz },
        { x: 65, y: 65 + ctrl.baz },
        { x: 85, y: 85 - ctrl.baz },
      ],
    },
    {
      label: 'Wednesday',
      data: [
        { x: 15, y: 25 + ctrl.baz },
        { x: 35, y: 35 - ctrl.baz },
        { x: 55, y: 30 + ctrl.baz },
        { x: 75, y: 55 - ctrl.baz },
        { x: 95, y: 75 + ctrl.baz },
      ],
    },
    {
      label: 'Thursday',
      data: [
        { x: 20, y: 40 - ctrl.baz },
        { x: 40, y: 50 + ctrl.baz },
        { x: 60, y: 35 - ctrl.baz },
        { x: 80, y: 70 + ctrl.baz },
        { x: 100, y: 90 - ctrl.baz },
      ],
    },
    {
      label: 'Friday',
      data: [
        { x: 12, y: 22 + ctrl.baz },
        { x: 32, y: 42 - ctrl.baz },
        { x: 52, y: 28 + ctrl.baz },
        { x: 72, y: 58 - ctrl.baz },
        { x: 92, y: 78 + ctrl.baz },
      ],
    },
  ],
}

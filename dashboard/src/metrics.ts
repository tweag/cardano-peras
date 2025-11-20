// Create a discrete representation of a continuous function f
export function discretize(
  f: (x: number) => number,
  min = 0,
  max = 10,
  resolution = 1000
): { x: number; y: number }[] {
  return Array.from({ length: resolution }, (_, x) => ({
    x: (x * (max - min)) / (resolution - 1) + min,
    y: f((x * (max - min)) / (resolution - 1) + min),
  }))
}

// Damped oscillator function
export function dampedOscillator(
  A: number,
  gamma: number,
  omega: number,
  x: number
) {
  return A * Math.exp(-gamma * x) * Math.cos(omega * x)
}

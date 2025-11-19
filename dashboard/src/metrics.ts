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

export function pPerasRollback(slot: number) {
  return Math.exp(-slot / 60)
}

export function pPraosRollback(slot: number) {
  return Math.exp(-slot / 180)
}

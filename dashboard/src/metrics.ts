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

export function dampedOscillator(
  A: number,
  gamma: number,
  omega: number,
  x: number
) {
  return A * Math.exp(-gamma * x) * Math.cos(omega * x)
}

export function pRollbackAfterOneBoost(
  adversaryStakeFraction: number,
  activeSlotCoefficient: number,
  U: number,
  L: number,
  B: number
) {
  const n = U + L
  const p = 1 - (1 - activeSlotCoefficient) ** (1 - adversaryStakeFraction)
  const q = 1 - (1 - activeSlotCoefficient) ** adversaryStakeFraction
  let s = new Array(n + 2).fill(0)
  s[1] = 1
  s = pEvolve(n, p, q, s, n)
  const s2 = new Array(n + 2).fill(0)
  for (let k = B + 1; k < n + 2; ++k) s2[k] = s[k - B]
  const sum = s2.reduce((acc, x) => acc + x, 0)
  s = s2.map((x) => x / sum)
  return pEvolve(n, p, q, s, 1000)
}

function pEvolve(
  n: number,
  p: number,
  q: number,
  s0: Array<number>,
  k: number
) {
  function adv(s: Array<number>) {
    const s1 = new Array(n + 2).fill(0)
    for (let k = 0; k < n + 2; ++k) {
      if (k == 0) {
        s1[0] = (1 - p) * q * s[1] + s[0]
      } else {
        let x = ((1 - p) * (1 - q) + p * q) * s[k]
        if (k > 1) x += p * (1 - q) * s[k - 1]
        if (k < n + 1) x += (1 - p) * q * s[k + 1]
        s1[k] = x
      }
    }
    return s1
  }
  let s = s0.slice()
  for (let i = 0; i < k; ++i) s = adv(s)
  return s
}

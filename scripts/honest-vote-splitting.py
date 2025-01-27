# See "Honest vote splitting" in the design doc for context

from scipy import stats

asc = 1 / 20
phi = lambda s: 1 - (1 - asc) ** s


def Psuccess(alpha, perasBlockMinSlots):
    H = stats.binom(perasBlockMinSlots, phi(1 - alpha))
    A = stats.binom(perasBlockMinSlots, phi(alpha))
    # P(H ≤ A)
    HleA = sum([A.pmf(x) * H.cdf(x) for x in range(perasBlockMinSlots + 1)])

    Hp = stats.geom(phi(1 - alpha))
    # P(Ap ≥ 1) where Ap ~ Binom(Hp, phi(alpha))
    cutoff = int(Hp.ppf(1 - 1e-10))
    Apge1 = sum([Hp.pmf(x) * stats.binom(x, phi(alpha)).sf(0) for x in range(cutoff)])

    return HleA * Apge1


for alpha in [0.05, 0.1, 0.15, 0.2]:
    for perasBlockMinSlots in [30, 60, 90, 120, 150, 300]:
        p = Psuccess(alpha, perasBlockMinSlots)
        print(f"alpha = {alpha}, L = {perasBlockMinSlots}: {p}")

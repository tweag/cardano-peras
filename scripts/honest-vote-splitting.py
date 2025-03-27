# See "Honest vote splitting" in the design doc for context

import matplotlib.pyplot as plt
import numpy as np
from scipy import stats

asc = 1 / 20
phi = lambda s: 1 - (1 - asc) ** s


def Psuccess(alpha, perasBlockMinSlots):
    H = stats.binom(perasBlockMinSlots, phi(1 - alpha))
    A = stats.binom(perasBlockMinSlots, phi(alpha))
    # P(H ≤ A)
    HleA = sum([A.pmf(x) * H.cdf(x) for x in range(perasBlockMinSlots + 1)])

    # P(Ap ≥ 1) where Ap ~ Binom(Hp, phi(alpha)) and Hp ~ Geom(phi(1-alpha))
    Apge1 = 1 - phi(1 - alpha) / asc

    return HleA * Apge1


perasBlockMinSlotsValues = [30, 60] + list(range(90, 990, 90))

for alpha in [0.05, 0.1, 0.15, 0.2]:
    for perasBlockMinSlots in perasBlockMinSlotsValues:
        p = Psuccess(alpha, perasBlockMinSlots)
        print(f"alpha = {alpha}, L = {perasBlockMinSlots}: {p}")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 6))

alpha = np.linspace(0, 0.25, num=20)

for perasBlockMinSlots in perasBlockMinSlotsValues:
    Ps = np.vectorize(lambda a: Psuccess(a, perasBlockMinSlots))(alpha)
    ax1.plot(alpha, Ps, label=f"perasBlockMinSlots = {perasBlockMinSlots}")
    expected = 90 / Ps / 3600 / 24 / 365
    ax2.plot(alpha, expected, label=f"perasBlockMinSlots = {perasBlockMinSlots}")

ax1.legend()
ax1.grid(True)
ax1.set_xlabel("adversarial stake")
ax1.set_ylabel("attack success probability")
ax1.set_yscale("log")

ax2.legend()
ax2.grid(True)
ax2.set_xlabel("adversarial stake")
ax2.set_ylabel("expected time until successful attack [year]")
ax2.set_yscale("log")

fig.tight_layout()
fig.savefig("plot-honest-vote-splitting.png", dpi=300, bbox_inches="tight")

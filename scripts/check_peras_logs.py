#!/usr/bin/env python3
"""Validate Peras testnet properties by reading the logs of a run.

Usage:
  scripts/check_peras_logs.py [RESULTS_DIR] [--wait SECONDS] [--poll SECONDS]

RESULTS_DIR defaults to devenv/logs-and-results and must contain
  logs/node<N>/{node.pid,stdout.log}
  logs/*_<port>/node-*.json      (cardano-tracer logs, one dir per node)
  <pid>_vote.blog                (side files written by the patched consensus)

Without --wait the logs are analysed once. With --wait the checks are re-run
every --poll seconds until none is PENDING (e.g. cooldown not yet entered or
not yet recovered from) or the timeout expires, so it can run next to a live
testnet.

Exit code: 0 all PASS/WARN, 1 some FAIL, 2 still PENDING at timeout.
"""
import argparse, collections, datetime, glob, json, os, re, sys, time
from fractions import Fraction as F

PASS, FAIL, WARN, PENDING = "PASS", "FAIL", "WARN", "PENDING"


def ts(s):
    s = s.rstrip("Z")
    if "." in s:
        a, b = s.split(".")
        s = a + "." + b.ljust(6, "0")[:6]
    return datetime.datetime.fromisoformat(s).timestamp()


class Run:
    def __init__(self, root):
        self.root = root
        self.nodes = {}
        for d in sorted(glob.glob(os.path.join(root, "logs", "node*"))):
            m = re.search(r"node(\d+)$", d)
            if not m:
                continue
            nd = {}
            try:
                nd["pid"] = open(os.path.join(d, "node.pid")).read().strip()
                head = open(os.path.join(d, "stdout.log"), errors="replace").read(200000)
                nd["port"] = re.search(r"ncNodePortNumber = Last \{getLast = Just (\d+)\}", head)[1]
            except (OSError, TypeError):
                continue
            self.nodes[int(m[1])] = nd
        for nd in self.nodes.values():
            self.load_blog(nd)
            self.load_tracer(nd)

    def load_blog(self, nd):
        path = os.path.join(self.root, f"{nd['pid']}_vote.blog")
        L = open(path, errors="replace").read().split("\n") if os.path.exists(path) else []
        nd["nokey"] = sum("Failed to read Peras pool ID" in l for l in L)
        nd["dec"] = {}       # round -> Vote | NoVote
        nd["notvoter"] = []
        nd["forged"] = {}    # round -> (seat, persistent)
        nd["incl_err"] = sum("TracePerasCertInclusionError" in l for l in L)
        for l in L:
            m = re.match(r"TracePerasVotingRulesDecision \(PerasRoundNo (\d+)\) \((Vote|NoVote)", l)
            if m:
                nd["dec"][int(m[1])] = m[2]
                continue
            m = re.match(r"TracePerasVotingNotAVoterInRound \(PerasRoundNo (\d+)", l)
            if m:
                nd["notvoter"].append(int(m[1]))
                continue
            m = re.match(r"Ticked vote:.*pvRoundNo = PerasRoundNo (\d+).*unPerasSeatIndex = (\d+)", l)
            if m:
                nd["forged"][int(m[1])] = (int(m[2]), "NonPersistentPerasVoteEligibilityProof" not in l)
        nd["resolver"] = next((l for l in L if l.startswith("PerasEpochContextResolver")), "")

    def load_tracer(self, nd):
        nd["votes"] = {}   # (round, seat) -> (time, generated cert, weight)
        nd["certs"] = []   # (round, time, result)
        nd["invalid_forged"] = 0
        for f in glob.glob(os.path.join(self.root, "logs", f"*_{nd['port']}", "node-*.json")):
            for l in open(f, errors="replace"):
                try:
                    j = json.loads(l)
                    t, ns, d = ts(j["at"]), j["ns"], j.get("data", {})
                except Exception:
                    continue
                if ns == "ChainDB.PerasVoteDbEvent.AddVote":
                    m = re.search(r"PerasRoundNo (\d+).*unPerasSeatIndex = (\d+)", d["voteId"])
                    w = re.search(r"unVoteWeight = (\d+) % (\d+)", d["result"])
                    nd["votes"][(int(m[1]), int(m[2]))] = (
                        t, "AndGenerated" in d["result"], F(int(w[1]), int(w[2])) if w else F(0))
                elif ns == "ChainDB.PerasCertDbEvent.AddCert":
                    nd["certs"].append((int(re.search(r"\d+", d["round"])[0]), t, d["result"]))
                elif ns == "Forge.Loop.ForgedInvalidBlock":
                    nd["invalid_forged"] += 1

    def threshold(self):
        for nd in self.nodes.values():
            q = re.search(r"PerasQuorumWeightThreshold \((\d+) % (\d+)\)", nd["resolver"])
            m = re.search(r"SafetyMargin \((\d+) % (\d+)\)", nd["resolver"])
            if q and m:
                return F(int(q[1]), int(q[2])) + F(int(m[1]), int(m[2]))
        return None


def checks(run):
    out = []

    def add(i, name, st, detail):
        out.append((i, name, st, detail))

    N = run.nodes
    if not N:
        return [("0", "logs found", FAIL, "no nodes under logs/")]
    keyless = [n for n, nd in N.items() if nd["nokey"] and not nd["dec"]]
    keyed = [n for n in N if n not in keyless]
    seat_node = {s: n for n in keyed for (s, _) in N[n]["forged"].values()}

    # 1. keyless nodes skip voting
    if not keyless:
        add(1, "keyless node skips voting", PENDING, "no node without a key found")
    else:
        bad = [n for n in keyless if N[n]["forged"]]
        add(1, "keyless node skips voting", FAIL if bad else PASS,
            ", ".join(f"node{n}: {N[n]['nokey']} no-key lines, 0 votes forged" for n in keyless))

    # 2. eligible SPOs vote
    problems, info = [], []
    for n in keyed:
        nd = N[n]
        vd = sorted(r for r, d in nd["dec"].items() if d == "Vote")
        fg = sorted(nd["forged"])
        persistent = bool(fg) and all(p for _, p in nd["forged"].values()) and not nd["notvoter"]
        if any(r not in vd for r in fg):
            problems.append(f"node{n} forged without a Vote decision")
        if persistent and fg != vd:
            problems.append(f"node{n} (persistent) voted {len(fg)}/{len(vd)} allowed rounds")
        info.append(f"node{n}: voted {len(fg)}/{len(vd)} allowed rounds" + (" (persistent)" if persistent else ""))
    if not any(nd["forged"] for nd in N.values()):
        add(2, "eligible SPO votes", PENDING, "no vote forged yet")
    else:
        add(2, "eligible SPO votes (persistent / non-persistent)", FAIL if problems else PASS,
            "; ".join(problems + info))

    # 3. not eligible -> no vote
    nv = {n: N[n]["notvoter"] for n in keyed if N[n]["notvoter"]}
    bad = [n for n in nv if set(nv[n]) & set(N[n]["forged"])]
    if not nv:
        add(3, "keyed node skips voting when not eligible", PENDING, "no NotAVoter round seen")
    else:
        add(3, "keyed node skips voting when not eligible", FAIL if bad else PASS,
            ", ".join(f"node{n}: {len(r)} rounds skipped" for n, r in nv.items()))

    # 4. non-persistent voters change
    npseats = collections.Counter(s for nd in N.values() for (s, p) in nd["forged"].values() if not p)
    if not npseats:
        add(4, "non-persistent voters change", PENDING, "no non-persistent vote yet")
    else:
        add(4, "non-persistent voters change", PASS if len(npseats) > 1 else WARN,
            f"votes per non-persistent seat: {dict(npseats)}"
            + ("" if len(npseats) > 1 else " (only one seat ever voted)"))

    # 5. vote diffusion
    sets = {n: set(nd["votes"]) for n, nd in N.items()}
    union = set().union(*sets.values())
    missing = {n: len(union - s) for n, s in sets.items() if union - s}
    if not union:
        add(5, "votes diffused to all nodes", PENDING, "no votes seen")
    else:
        lat = []
        for k in union:
            o = seat_node.get(k[1])
            if o and k in N[o]["votes"]:
                t0 = N[o]["votes"][k][0]
                lat += [(N[n]["votes"][k][0] - t0, n, k) for n in N if n != o and k in N[n]["votes"]]
        ls = sorted(x[0] for x in lat)
        slow = [(round(l, 1), n, k) for l, n, k in lat if l > 1]
        d = f"{len(union)} distinct votes"
        if ls:
            d += f"; latency median {ls[len(ls)//2]*1000:.0f} ms, max {ls[-1]*1000:.0f} ms ({len(ls)} samples)"
        if slow:
            d += f"; {len(slow)} samples > 1 s, e.g. (latency, node, vote) = {slow[0]}"
        if missing:
            d += f"; votes missing per node: {missing}"
        add(5, "votes diffused to all nodes", FAIL if missing else (WARN if slow else PASS), d)

    # 6. cert generated exactly at quorum
    thr = run.threshold()
    gen_rounds, anomalies = set(), []
    for n, nd in N.items():
        byr = collections.defaultdict(list)
        for k, v in nd["votes"].items():
            byr[k[0]].append(v)
        for r, vs in byr.items():
            cum = F(0)
            for t, gen, w in sorted(vs, key=lambda x: x[0]):
                before, cum = cum, cum + w
                if gen:
                    gen_rounds.add(r)
                if thr is not None and gen != (before < thr <= cum):
                    anomalies.append((n, r, float(before), float(cum), gen))
    if thr is None or not gen_rounds:
        add(6, "cert generated when quorum reached", PENDING, "no quorum threshold / cert yet")
    else:
        add(6, "cert generated when quorum reached", FAIL if anomalies else PASS,
            f"threshold {float(thr):.3f}; certs generated in rounds {sorted(gen_rounds)}"
            + (f"; anomalies (node, round, before, after, generated): {anomalies[:3]}" if anomalies else ""))

    # 7. no second generation
    dup = [(n, r, x) for n, nd in N.items()
           for r, x in collections.Counter(k[0] for k, v in nd["votes"].items() if v[1]).items() if x > 1]
    add(7, "no second cert generation", FAIL if dup else (PASS if gen_rounds else PENDING),
        f"duplicates (node, round, count): {dup}" if dup else "exactly one generating vote per round per node")

    # 8. certs reach every node's CertDB (diffusion / local add)
    absent = {r: [n for n, nd in N.items() if not any(c[0] == r for c in nd["certs"])]
              for r in sorted(gen_rounds)}
    absent = {r: m for r, m in absent.items() if m}
    already = sum(1 for nd in N.values() for c in nd["certs"] if c[2].startswith("PerasCertAlready"))
    if not gen_rounds:
        add(8, "certs reach every node's CertDB", PENDING, "no cert yet")
    else:
        d = (f"generated by VoteDB but missing from CertDB (round: nodes): {absent}"
             if absent else "all generated certs present on all nodes")
        add(8, "certs reach every node's CertDB", FAIL if absent else PASS,
            d + f"; {already} PerasCertAlreadyInDB events")

    # 9/10. cooldown and recovery
    cd, rec = [], []
    for n in keyed:
        d = N[n]["dec"]
        rounds = sorted(d)
        first_no = next((r for r in rounds if d[r] == "NoVote"
                         and any(d[q] == "Vote" for q in rounds if q < r)), None)
        if first_no is not None:
            cd.append((n, first_no))
            back = next((r for r in rounds if r > first_no and d[r] == "Vote"), None)
            if back is not None:
                rec.append((n, first_no, back))
    if not cd:
        add(9, "cooldown entered", PENDING, "no NoVote round after voting yet")
        add(10, "cooldown recovery", PENDING, "not in cooldown")
    else:
        add(9, "cooldown entered", PASS, "first NoVote round: " + ", ".join(f"node{n}: r{r}" for n, r in cd))
        stuck = [n for n, _ in cd if n not in {x[0] for x in rec}]
        if stuck:
            add(10, "cooldown recovery", PENDING, f"no vote after cooldown yet on nodes {stuck}")
        else:
            add(10, "cooldown recovery", PASS, ", ".join(f"node{n}: r{a} -> r{b}" for n, a, b in rec))

    # informational anomalies
    inv = {n: nd["invalid_forged"] for n, nd in N.items() if nd["invalid_forged"]}
    ie = {n: nd["incl_err"] for n, nd in N.items() if nd["incl_err"]}
    add("A1", "locally forged invalid blocks", WARN if inv else PASS, str(inv) if inv else "none")
    add("A2", "cert inclusion errors", WARN if ie else PASS, str(ie) if ie else "none")
    return out


def report(out):
    colour = {PASS: "\033[32m", FAIL: "\033[31m", WARN: "\033[33m", PENDING: "\033[36m"}
    for i, name, st, detail in out:
        s = f"{colour[st]}{st:7}\033[0m" if sys.stdout.isatty() else f"{st:7}"
        print(f"[{s}] {i}. {name}\n          {detail}")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("results", nargs="?", default=os.path.join(here, "..", "devenv", "logs-and-results"))
    ap.add_argument("--wait", type=float, default=0, help="keep re-checking up to this many seconds")
    ap.add_argument("--poll", type=float, default=15)
    a = ap.parse_args()
    deadline = time.time() + a.wait
    while True:
        out = checks(Run(a.results))
        pend = [c for c in out if c[2] == PENDING]
        if not pend or time.time() >= deadline:
            break
        print(f"... {len(pend)} check(s) pending, retrying in {a.poll:.0f}s", file=sys.stderr)
        time.sleep(a.poll)
    report(out)
    if any(c[2] == FAIL for c in out):
        sys.exit(1)
    sys.exit(2 if pend else 0)


if __name__ == "__main__":
    main()

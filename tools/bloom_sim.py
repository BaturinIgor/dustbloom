#!/usr/bin/env python3
"""Bloom balance bots.

Plays the Bloom slice with simple greedy bots and reports how long it takes to
finish every goal and buy every island, with and without donate.

    python3 tools/bloom_sim.py            # table for all personas
    python3 tools/bloom_sim.py --runs 40  # more runs per persona
    python3 tools/bloom_sim.py --log f2p  # timeline of one run

Numbers come from client/Dustbloom/Core/Bloom/bloom_balance.json (the same file
the game reads) and bloom_world.json (island caps and spawn tables). Timing
constants mirror BloomScene: one swing every ~0.33 s, helper hit every 0.9 s.
"""
import argparse, json, math, os, random, statistics

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAL = json.load(open(os.path.join(ROOT, "client/Dustbloom/Core/Bloom/bloom_balance.json")))
WORLD = json.load(open(os.path.join(ROOT, "client/Dustbloom/Core/Bloom/bloom_world.json")))

SWING = 0.33           # seconds between hero hits
HELPER_HIT = 0.9       # seconds between helper hits
HELPER_WALK = 1.6      # helper walk overhead per node
SESSION = 15 * 60      # a typical play session (for ad cooldowns)
STONES = {"rock", "rock_iron", "rock_gold", "crystal", "dune", "obsidian", "starstone"}
ISLAND_ITEMS = {1: "cotton", 2: "iron_ore", 4: "gold_ore", 5: "crystal"}

# What the bots learn first: the talents a real player would pick for speed.
TALENT_ORDER = ["d1", "t1", "d2", "b2", "t2", "h1", "d3", "h2", "c1", "c2", "h3", "t4",
                "d4", "b4", "t3", "h4", "c3", "b1", "b3", "d5", "c4", "c5", "b5", "t5", "h5"]


def talent_cost(tid):
    return 2 if int(tid[1]) >= 4 else 1


class Persona:
    def __init__(self, name, ads=False, founder=False, pass_=False, gems_per_hour=0, label=""):
        self.name, self.ads, self.founder, self.pass_ = name, ads, founder, pass_
        self.gems_per_hour, self.label = gems_per_hour, label


PERSONAS = [
    Persona("f2p", label="Без доната, без рекламы"),
    Persona("f2p_ads", ads=True, label="Без доната, смотрит рекламу"),
    Persona("minnow", ads=True, founder=True, label="Набор основателя $4.99"),
    Persona("dolphin", ads=True, founder=True, pass_=True, label="Основатель + Пропуск ($12)"),
    Persona("whale", ads=True, founder=True, pass_=True, gems_per_hour=400, label="Кит (~$40+)"),
]

SHOP = BAL.get("shop", {})


class Sim:
    def __init__(self, p: Persona, seed=0, log=False):
        self.p, self.rng, self.log_on = p, random.Random(seed), log
        self.t = 0.0
        self.inv = {}
        self.coins, self.xp, self.level, self.gems = 0, 0, 1, 0
        self.owned = [0]
        self.built = set()
        self.pick, self.lucky = 0, False
        self.axe, self.shovel, self.next_dig, self.gathers = 0, False, 0.0, 0
        self.helpers = 0            # grown helpers
        self.golden_helper = False  # founder pack helper (does not take a slot)
        self.talents = []
        self.stats = {}
        self.goal = 0
        self.nodes = {i: {} for i in range(len(WORLD["islands"]))}
        self.flowers = 0
        self.respawn_acc = 0.0
        self.flower_timer = 0
        self.golden_until = -1
        self.next_golden = BAL.get("golden", {}).get("first", 75)
        self.next_ad = 0.0
        self.combo = 0
        self.queues = []  # (done_at, item, n)
        self.events = []
        self.helper_acc = 0.0
        self.chest_free = 0.0
        self.fert_until = -1.0
        for k, n in WORLD["islands"][0]["spawn"].items():
            self.nodes[0][k] = n
        self.flowers = 2
        if p.founder:
            f = SHOP.get("founder", {})
            self.gems += f.get("gems", 0)
            self.golden_helper = True
        self.prices = BAL["islandPrices"]

    # ---------- helpers ----------
    def has_t(self, t): return t in self.talents
    def cnt(self, i): return self.inv.get(i, 0)
    def add(self, i, n):
        self.inv[i] = self.cnt(i) + n
        self.stats["item." + i] = self.stats.get("item." + i, 0) + n
    def has(self, cost, times=1): return all(self.cnt(i) >= n * times for i, n in cost)
    def pay(self, cost, times=1):
        for i, n in cost: self.inv[i] -= n * times
    def log(self, msg):
        self.events.append((self.t, msg))
        if self.log_on: print(f"{self.t/60:7.1f} min  L{self.level:<2} {self.coins:>5}c  {msg}")

    @property
    def golden(self): return self.t < self.golden_until
    @property
    def damage(self):
        d = BAL["picks"][self.pick]["damage"] + (1 if self.lucky else 0) + (1 if self.has_t("d1") else 0)
        return d
    @property
    def crit(self): return BAL.get("critChance", 0.1) + (0.06 if self.has_t("d2") else 0)
    def xp_to_next(self, L):
        x = BAL["xp"]; return x["base"] + x["lin"] * L + x["quad"] * L * L
    @property
    def pass_mult(self): return SHOP.get("pass", {}).get("dropBonus", 0) if self.p.pass_ else 0
    @property
    def max_helpers(self): return BAL.get("maxHelpers", 3) + (1 if self.has_t("h4") else 0)
    def helper_cost(self):
        c = BAL["helperCost"]; n = self.helpers
        cost = [(k, v[0] + v[1] * n) for k, v in c.items()]
        if self.has_t("h1"): cost = [(k, math.ceil(v * 0.7)) for k, v in cost]
        return cost
    def build_cost(self, b):
        c = [tuple(x) for x in BAL["buildings"][b]["cost"]]
        return [(k, math.ceil(v * 0.8)) for k, v in c] if self.has_t("c2") else c
    def island_price(self, i):
        p = self.prices[i]; return round(p * 0.8) if self.has_t("t4") else p
    def sell_price(self, i):
        p = BAL["prices"][i]; return math.ceil(p * 1.25) if self.has_t("t1") else p
    def respawn_interval(self):
        base = BAL.get("respawnSeconds", 2.2)
        per = BAL.get("respawnPerIsland", 0)
        iv = base / (1 + per * (len(self.owned) - 1)) if per else base
        if self.has_t("b2"): iv /= 1.4
        if self.p.founder: iv /= 1 + SHOP.get("founder", {}).get("regrowBonus", 0)
        if self.t < self.fert_until: iv /= SHOP.get("fertilizer", {}).get("mult", 2)
        return iv

    # ---------- xp / goals ----------
    def gain_xp(self, n):
        if self.p.pass_: n = math.ceil(n * (1 + SHOP.get("pass", {}).get("xpBonus", 0)))
        self.xp += n
        while self.xp >= self.xp_to_next(self.level):
            self.xp -= self.xp_to_next(self.level); self.level += 1
            self.log(f"уровень {self.level}")

    def stat(self, key):
        if key == "islands": return len(self.owned)
        if key == "level": return self.level
        if key == "pick": return self.pick
        if key == "axe": return self.axe
        if key == "shovel": return 1 if self.shovel else 0
        if key == "helpers": return self.helpers
        if key.startswith("build."): return 1 if key[6:] in self.built else 0
        return self.stats.get(key, 0)

    def goal_target(self, g):
        if g["key"].startswith(("item.", "gather.", "craft.")):
            return max(1, round(g["target"] * BAL.get("goalScale", 1)))
        return g["target"]

    def claim_goals(self):
        goals = BAL["goals"]
        while self.goal < len(goals) and self.stat(goals[self.goal]["key"]) >= self.goal_target(goals[self.goal]):
            g = goals[self.goal]; self.goal += 1
            self.coins += g["coins"]; self.gain_xp(g["xp"])
            self.log(f"цель «{g['title']}»")

    # ---------- world ----------
    def tick_world(self, dt):
        # respawn
        self.respawn_acc += dt
        iv = self.respawn_interval()
        while self.respawn_acc >= iv:
            self.respawn_acc -= iv
            self.respawn_one()
        # golden hour
        gh = BAL.get("golden", {})
        if self.t >= self.next_golden:
            dur = gh.get("duration", 25) * (1.5 if self.has_t("b4") else 1)
            self.golden_until = self.t + dur
            self.next_golden = self.t + gh.get("every", 240)
        # whales keep the fertilizer on (gems)
        fz = SHOP.get("fertilizer", {})
        if self.p.gems_per_hour and self.t >= self.fert_until and self.gems >= fz.get("gems", 40):
            self.gems -= fz.get("gems", 40); self.fert_until = self.t + fz.get("minutes", 10) * 60
        # rewarded ad / gems: golden hour on demand
        if self.p.ads and self.t >= self.next_ad and not self.golden:
            ad = SHOP.get("adGolden", {})
            self.golden_until = self.t + ad.get("duration", 60)
            self.next_ad = self.t + ad.get("cooldown", 600)
        # crafting queues
        done = [q for q in self.queues if q[0] <= self.t]
        for q in done:
            self.queues.remove(q)
            n = q[2]
            if self.has_t("c3"):
                n += sum(1 for _ in range(q[2]) if self.rng.random() < 0.2)
            self.inv[q[1]] = self.cnt(q[1]) + n
            self.stats["craft." + q[1]] = self.stats.get("craft." + q[1], 0) + n
        # helpers chew through nodes on their own
        hp_rate = (self.helpers + (SHOP.get("founder", {}).get("helperPower", 2) if self.golden_helper else 0)) * (2 if self.has_t("h3") else 1) * (1.4 if self.has_t("h2") else 1)
        if hp_rate:
            self.helper_acc += dt * hp_rate
            while True:
                k, isl = self.pick_node(for_helper=True)
                if k is None: break
                need = BAL["gather"][k]["hp"] * HELPER_HIT + HELPER_WALK
                if self.helper_acc < need: break
                self.helper_acc -= need
                self.destroy(k, isl, mult=1, hero=False)
            self.helper_acc = min(self.helper_acc, 10)

    def respawn_one(self):
        ch = BAL["chest"]
        if self.t >= self.chest_free and self.rng.random() < ch["chance"] * (2 if self.has_t("t3") else 1) * (2 if self.golden else 1):
            self.chest_free = self.t + ch.get("cooldown", 0)
            self.open_chest()
        cands = [i for i in self.owned if sum(self.nodes[i].values()) < WORLD["islands"][i]["cap"]]
        if not cands: return
        i = self.rng.choice(cands)
        sp = WORLD["islands"][i]["spawn"]
        k = self.rng.choices(list(sp), weights=list(sp.values()))[0]
        self.nodes[i][k] = self.nodes[i].get(k, 0) + 1
        self.flower_timer += 1
        if self.flower_timer >= 4:
            self.flower_timer = 0
            if self.flowers < len(self.owned) * 3 * (2 if self.has_t("b1") else 1):
                self.flowers += 1

    def open_chest(self):
        # chests sit on the map; the bot walks over when it passes by (~4 s)
        self.t += 4
        self.stats["chest"] = self.stats.get("chest", 0) + 1
        tier = len(self.owned)
        ch = BAL["chest"]
        self.coins += self.rng.randint(ch["coinsMin"], ch["coinsMax"]) + tier * ch["coinsPerIsland"]
        pool = ["wood", "stone", "berry", "flower"]
        if 1 in self.owned or 3 in self.owned: pool.append("cotton")
        if 2 in self.owned: pool += ["iron_ore", "brick"]
        if 4 in self.owned: pool += ["gold_ore", "iron_bar"]
        if 5 in self.owned: pool.append("crystal")
        for isl, its in ((6, ["sand", "glass"]), (7, ["fish"]), (8, ["mushroom"]), (9, ["honey", "jam"]),
                         (10, ["obsidian"]), (11, ["stardust"])):
            if isl in self.owned: pool += its
        for i in self.rng.sample(pool, 3):
            n = self.rng.randint(1, 2) if i in ("crystal", "gold_ore", "iron_bar", "glass", "jam", "obsidian", "stardust") else self.rng.randint(3, 6)
            self.add(i, n)

    # ---------- what does the bot want ----------
    def wanted(self):
        """Items the next purchases need, in amounts."""
        need = {}
        def want(cost, times=1):
            for i, n in cost: need[i] = need.get(i, 0) + n * times
        for b, d in BAL["buildings"].items():
            if b not in self.built and self.level >= d["level"]: want(self.build_cost(b))
        if self.pick + 1 < len(BAL["picks"]): want([tuple(x) for x in BAL["picks"][self.pick + 1]["cost"]])
        if self.axe + 1 < len(BAL["axes"]): want([tuple(x) for x in BAL["axes"][self.axe + 1]["cost"]])
        if not self.shovel: want([tuple(x) for x in BAL["shovel"]["cost"]])
        if "nursery" in self.built and self.helpers < self.max_helpers: want(self.helper_cost())
        if self.goal < len(BAL["goals"]):
            g = BAL["goals"][self.goal]; k = g["key"]
            if k.startswith(("item.", "craft.")):
                it = k.split(".", 1)[1]
                left = self.goal_target(g) - self.stat(k)
                if left > 0:
                    if k.startswith("craft."): need[it] = need.get(it, 0) + self.cnt(it) + left
                    else: need[it] = need.get(it, 0) + left
        # expand crafted items to raw
        raw = {}
        for i, n in need.items():
            short = max(0, n - self.cnt(i))
            if i in BAL["recipes"] and short:
                for ri, rn in BAL["recipes"][i]["cost"]: raw[ri] = raw.get(ri, 0) + rn * short
            raw[i] = raw.get(i, 0) + n
        return raw

    def pick_node(self, for_helper=False):
        """Choose the most useful node on the owned islands."""
        need = self.wanted()
        best, bi, bs = None, None, -1
        for i in self.owned:
            for k, n in self.nodes[i].items():
                if n <= 0: continue
                d = BAL["gather"][k]
                score = d["xp"] * 0.3 + 1
                for it, lo, hi, ch in d["drops"]:
                    short = need.get(it, 0) - self.cnt(it)
                    v = BAL["prices"].get(it, 1) * (lo + hi) / 2 * ch
                    score += v * (3 if short > 0 else 1)
                score /= d["hp"] + 3
                if score > bs: best, bi, bs = k, i, score
        return best, bi

    # ---------- actions ----------
    def destroy(self, k, isl, mult, hero=True):
        d = BAL["gather"][k]
        self.nodes[isl][k] -= 1
        gk = {"pine": "tree", "palm": "tree", "rock_iron": "rock", "rock_gold": "rock", "crystal": "rock",
              "dune": "rock", "obsidian": "rock", "starstone": "rock",
              "bush_berry": "bush", "bush_cotton": "bush", "mushroom": "bush", "hive": "bush"}.get(k, k)  # same groups as BloomGame.gathered
        self.stats["gather." + gk] = self.stats.get("gather." + gk, 0) + 1
        g = 2 if self.golden else 1
        for it, lo, hi, ch in d["drops"]:
            if self.rng.random() < ch:
                n = self.rng.randint(lo, hi)
                if mult > 1: n += (mult - 1) // BAL["combo"].get("bonusDiv", 1)
                if self.has_t("d4") and self.rng.random() < 0.15: n *= 2
                n = n * g
                if self.pass_mult and self.rng.random() < self.pass_mult: n += 1
                self.add(it, n)
                mult = 1
        ch = (BAL["coinChance"] + 0.06 * (mult - 1) + (0.1 if k in STONES else 0)) * (1.5 if self.has_t("t2") else 1)
        if self.rng.random() < ch:
            self.coins += self.rng.randint(1, 3 if k in STONES else 2) * g
        self.gain_xp(d["xp"])

    def hero_gather(self):
        k, isl = self.pick_node()
        if k is None:
            self.advance(0.5)  # nothing to hit: wait for respawn
            return
        d = BAL["gather"][k]
        walk = self.rng.uniform(0.5, 1.7) + 0.05 * len(self.owned)
        window = BAL["combo"]["window"] + (0.4 if self.has_t("d3") else 0)
        if walk > window: self.combo = 0
        self.advance(walk)
        hp = d["hp"]; hits = 0
        while hp > 0:
            hits += 1; self.combo += 1
            step = min(BAL["combo"]["max"], 1 + self.combo // BAL["combo"]["hitsPerStep"])
            crit = self.rng.random() < self.crit + 0.02 * (step - 1)
            dmg = self.damage + (BAL["axes"][self.axe]["bonus"] if k in ("tree", "pine", "palm") else 0)
            hp -= dmg * 2 + 1 if crit else dmg
        self.stats["combo"] = max(self.stats.get("combo", 0), min(BAL["combo"]["max"], 1 + self.combo // BAL["combo"]["hitsPerStep"]))
        self.advance(hits * SWING)
        if self.nodes[isl].get(k, 0) > 0:
            self.destroy(k, isl, min(BAL["combo"]["max"], 1 + self.combo // BAL["combo"]["hitsPerStep"]))
            self.gathers += 1
            if self.gathers % 24 == 0: self.stats["happening"] = self.stats.get("happening", 0) + 1
            # dust creatures from level 5: roughly one fight per 12 gathers, a few seconds each
            if self.level >= 5 and self.gathers % 12 == 0:
                self.advance(3); self.stats["kill"] = self.stats.get("kill", 0) + 1; self.coins += 3 + len(self.owned) * 2
        # flowers along the way
        if self.flowers and self.rng.random() < 0.25:
            self.flowers -= 1; self.add("flower", 1)
            if self.has_t("b3"): self.gain_xp(5)

    def advance(self, dt):
        while dt > 0:
            s = min(dt, 0.5); self.t += s; dt -= s
            self.tick_world(s)

    def manage(self):
        """Spend: talents, buildings, picks, islands, helpers, crafting, selling."""
        self.claim_goals()
        spent = sum(talent_cost(t) for t in self.talents)
        for tid in TALENT_ORDER:
            if tid in self.talents: continue
            br, tier = tid[0], int(tid[1])
            if tier > 1 and f"{br}{tier-1}" not in self.talents: continue
            if (self.level - 1) - spent >= talent_cost(tid):
                self.talents.append(tid); spent += talent_cost(tid)
        for b, d in BAL["buildings"].items():
            if b not in self.built and self.level >= d["level"] and self.has(self.build_cost(b)):
                self.pay(self.build_cost(b)); self.built.add(b); self.advance(3); self.log(f"построил {b}")
        if "anvil" in self.built and self.pick + 1 < len(BAL["picks"]):
            c = [tuple(x) for x in BAL["picks"][self.pick + 1]["cost"]]
            if self.has(c):
                self.pay(c); self.pick += 1
                self.lucky = self.rng.random() < 0.25 + (0.25 if self.has_t("c4") else 0)
                self.log(f"кирка {self.pick}"); self.advance(3)
        if "anvil" in self.built and self.axe + 1 < len(BAL["axes"]):
            c = [tuple(x) for x in BAL["axes"][self.axe + 1]["cost"]]
            if self.has(c):
                self.pay(c); self.axe += 1; self.log(f"топор {self.axe}"); self.advance(3)
        if "anvil" in self.built and not self.shovel and self.has([tuple(x) for x in BAL["shovel"]["cost"]]):
            self.pay([tuple(x) for x in BAL["shovel"]["cost"]]); self.shovel = True; self.next_dig = self.t + 20
            self.log("лопата"); self.advance(3)
        if self.shovel and self.level >= 3 and self.t >= self.next_dig:
            # walk to the mound and dig: a few seconds, coins and some goods
            self.next_dig = self.t + BAL["shovel"]["every"] * self.rng.uniform(0.8, 1.3)
            self.advance(4)
            self.coins += self.rng.randint(6, 12) + self.level * 2 + len(self.owned) * 3
            self.stats["dig"] = self.stats.get("dig", 0) + 1
        if "nursery" in self.built and self.helpers < self.max_helpers and self.has(self.helper_cost()):
            self.pay(self.helper_cost()); self.helpers += 1; self.log(f"помощник {self.helpers}"); self.advance(3)
        # next island
        nxt = len(self.owned)
        if nxt < len(self.prices):
            # whales top up coins with gems for the island
            if self.p.gems_per_hour and self.coins < self.island_price(nxt):
                rate = SHOP.get("gemCoins", 10)
                need_g = math.ceil((self.island_price(nxt) - self.coins) / rate)
                if self.gems >= need_g: self.gems -= need_g; self.coins += need_g * rate
            if self.coins >= self.island_price(nxt):
                self.coins -= self.island_price(nxt); self.owned.append(nxt)
                for k, n in WORLD["islands"][nxt]["spawn"].items(): self.nodes[nxt][k] = self.nodes[nxt].get(k, 0) + n
                self.flowers += 2
                self.log(f"купил остров {nxt} «{WORLD['islands'][nxt]['name']}»"); self.advance(4)
        # crafting: keep the furnace busy with what is needed
        need = self.wanted()
        busy = {r["at"] for (_, it, _) in self.queues for r in [BAL["recipes"][it]]}
        for it, r in BAL["recipes"].items():
            if r["at"] not in self.built or r["at"] in busy: continue
            short = need.get(it, 0) - self.cnt(it)
            if short <= 0: continue
            cost = [tuple(x) for x in r["cost"]]
            n = min(short, min(self.cnt(i) // c for i, c in cost))
            if n <= 0: continue
            self.pay(cost, n)
            secs = r["seconds"] * (0.75 if self.has_t("c1") else 1) * (0.7 if self.has_t("c5") else 1)
            self.queues.append((self.t + secs * n, it, n)); busy.add(r["at"])
            self.advance(2)
        # sell surplus when the market is up and an island is the next big thing
        if "market" in self.built:
            sold = 0
            for it in BAL["prices"]:
                keep = need.get(it, 0) + (5 if it in ("berry", "flower") else 0)
                extra = self.cnt(it) - keep
                if extra > 0 and it not in ("crystal",) or (it == "crystal" and extra > 0 and self.goal >= len(BAL["goals"])):
                    self.inv[it] -= extra; self.coins += int(extra * self.sell_price(it) * BAL.get("sellRate", 1)); sold += extra
            if sold: self.advance(2)

    def done(self):
        return self.goal >= len(BAL["goals"]) and len(self.owned) >= len(self.prices)

    def run(self, limit_h=300):
        marks = {}
        lv_marks = {}
        last_hour = 0
        while not self.done() and self.t < limit_h * 3600:
            self.manage()
            self.hero_gather()
            h = int(self.t // 3600)
            if self.p.gems_per_hour and h > last_hour:
                self.gems += self.p.gems_per_hour * (h - last_hour); last_hour = h
            if len(self.owned) - 1 not in marks: marks[len(self.owned) - 1] = self.t
            for L in (5, 10, 15, 20, 25):
                if self.level >= L and L not in lv_marks: lv_marks[L] = self.t
        return {"total": self.t, "islands": marks, "levels": lv_marks, "level": self.level,
                "goals": self.goal, "done": self.done()}


def fmt(sec):
    if sec is None: return "—"
    h, m = divmod(int(sec // 60), 60)
    return f"{h}ч {m:02d}м" if h else f"{m}м"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=20)
    ap.add_argument("--log")
    ap.add_argument("--md", help="write a markdown table here")
    a = ap.parse_args()
    if a.log:
        p = next(x for x in PERSONAS if x.name == a.log)
        r = Sim(p, seed=1, log=True).run(); print(fmt(r["total"]), r); return
    rows = []
    for p in PERSONAS:
        res = [Sim(p, seed=s).run() for s in range(a.runs)]
        med = lambda xs: statistics.median(xs) if xs else None
        isl = {i: med([r["islands"][i] for r in res if i in r["islands"]]) for i in range(1, len(BAL["islandPrices"]))}
        lv = {L: med([r["levels"][L] for r in res if L in r["levels"]]) for L in (5, 10, 15, 20)}
        rows.append((p, med([r["total"] for r in res]), isl, lv, med([r["level"] for r in res]),
                     sum(r["done"] for r in res)))
    shown = [3, 5, 6, 8, 10, 11]
    head = "| Игрок | Пройти всё | " + " | ".join(f"Остров {i + 1}" for i in shown) + " | Ур. 5 | Ур. 10 | Ур. 15 | Финальный ур. |"
    out = [head, "|" + "---|" * (len(shown) + 6)]
    for p, tot, isl, lv, L, ok in rows:
        out.append(f"| {p.label} | {fmt(tot)} | " + " | ".join(fmt(isl.get(i)) for i in shown) +
                   f" | {fmt(lv[5])} | {fmt(lv[10])} | {fmt(lv[15])} | {L:.0f} |")
    print("\n".join(out))
    if a.md: open(a.md, "w").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()

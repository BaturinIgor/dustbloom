#!/usr/bin/env python3
"""Writes the working buildings (and manor Мощь) into the balance file.

Run from the repo root: python3 scripts/gen_buildings.py
Every building has 30 levels; a level can never pass the manor's level.
"""
import json
import pathlib

PATH = pathlib.Path("server/internal/game/data/crops.json")
MAX = 30

# (id, ru, en, effect, perLevel %, cap %, unlockManor, startLevel, coins, coinGrowth, seconds, secGrowth, power)
SPECS = [
    ("well", "Колодец", "Well", "grow", 1.5, 45, 2, 0, 40, 1.32, 20, 1.33, 8),
    ("mill", "Мельница", "Mill", "sell", 2, 60, 1, 1, 60, 1.32, 25, 1.33, 10),
    ("workshop", "Мастерская", "Workshop", "build_time", 2, 50, 1, 1, 50, 1.32, 25, 1.33, 12),
    ("order_board", "Доска заказов", "Order board", "order_reward", 3, 90, 1, 1, 45, 1.32, 20, 1.33, 8),
    ("forge", "Кузница", "Forge", "army_power", 2, 60, 4, 0, 120, 1.32, 40, 1.32, 20),
    ("watchtower", "Дозорная башня", "Watchtower", "raid_cooldown", 2, 50, 6, 0, 150, 1.32, 45, 1.32, 15),
]

# which crop each band of levels asks for
BANDS = [(3, "dustwheat"), (6, "emberpumpkin"), (9, "ashcarrot"), (12, "moonturnip"),
         (15, "ironbean"), (18, "frostcabbage"), (21, "emberpepper"), (24, "glowmelon"), (27, "stormcorn")]


def band(level):
    out = None
    for i, (start, crop) in enumerate(BANDS):
        if level >= start:
            out = i
    return out


def crops_for(level, coins, prices, grow):
    i = band(level)
    if i is None:
        return {}
    need = {}
    picks = [BANDS[i][1]] + ([BANDS[i - 1][1]] if i > 0 and level >= 10 else [])
    for k, crop in enumerate(picks):
        value = coins * (0.15 if k == 0 else 0.08)
        # slow crops are asked for in small numbers
        need[crop] = max(2, min(40, round(86400 / grow[crop]), round(value / prices[crop])))
    return need


def main():
    cfg = json.loads(PATH.read_text())
    prices = {c["id"]: c["sellPrice"] for c in cfg["crops"]}
    grow = {c["id"]: c["growSeconds"] for c in cfg["crops"]}
    out = []
    for (bid, ru, en, effect, per, cap, unlock, start, coins, cg, secs, sg, power) in SPECS:
        levels = []
        for lvl in range(1, MAX + 1):
            c = round(coins * cg ** (lvl - 1) / 5) * 5
            levels.append({
                "coins": c,
                "crops": crops_for(lvl, c, prices, grow),
                "seconds": round(secs * sg ** (lvl - 1)),
                "power": round(power * 1.2 ** (lvl - 1)),
            })
        out.append({"id": bid, "name": {"ru": ru, "en": en}, "effect": effect, "perLevel": per,
                    "cap": cap, "unlockManor": unlock, "startLevel": start, "levels": levels})
    cfg["buildings"] = {"list": out}
    # the manor gives the most Мощь of any building
    for i, l in enumerate(cfg["manor"]["levels"]):
        l["power"] = round(40 * 1.22 ** i)
    cfg["manor"]["startPower"] = 30
    cfg["version"] = max(cfg["version"], 8)
    PATH.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n")
    for b in out:
        tot = sum(l["seconds"] for l in b["levels"][b["startLevel"]:]) / 3600
        print(f'{b["id"]:12} L30 coins {b["levels"][-1]["coins"]:>8} secs {b["levels"][-1]["seconds"]:>6} total {tot:6.1f} h  crops30 {b["levels"][-1]["crops"]}')


if __name__ == "__main__":
    main()

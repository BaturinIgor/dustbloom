#!/usr/bin/env python3
"""Reports in-game strings that have no translation yet.
Keys are the Russian texts passed to tr("...") plus goal titles and island names."""
import glob, json, re, sys
root = "client/Dustbloom"
keys = set()
for f in glob.glob(root + "/**/*.swift", recursive=True):
    src = open(f).read()
    keys |= set(re.findall(r'\btr\("((?:[^"\\]|\\.)*)"', src))
    # data tables translated at display time: title:/text: literals with Cyrillic
    keys |= {k for k in re.findall(r'\b(?:title|text|relicTitle|relicText): "((?:[^"\\]|\\.)*)"', src) if re.search('[А-Яа-яЁё]', k)}
b = json.load(open(root + "/Core/Bloom/bloom_balance.json"))
w = json.load(open(root + "/Core/Bloom/bloom_world.json"))
keys |= {g["title"] for g in b["goals"]} | {i["name"] for i in w["islands"]}
bad = 0
for f in sorted(glob.glob(root + "/Resources/i18n/bloom_i18n_*.json")):
    t = json.load(open(f))
    miss = sorted(k for k in keys if k not in t)
    if miss:
        bad += 1
        print(f.split("_")[-1][:-5], "missing", len(miss), miss[:5])
print(len(keys), "keys;", "all languages complete" if not bad else f"{bad} languages incomplete")
sys.exit(1 if bad else 0)

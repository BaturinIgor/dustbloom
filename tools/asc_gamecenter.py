#!/usr/bin/env python3
"""Creates the Bloom Game Center leaderboards and achievements in App Store Connect.
Idempotent: what already exists is left alone. IDs must match BloomGameCenter.swift.
Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH. Achievement images are drawn from the game sprites."""
import argparse, io, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_iap import ASC, BUNDLE_ID  # noqa: E402
from gc_locales import ACH as ACH_L, LB as LB_L  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "client/Dustbloom/Assets.xcassets")

LEADERBOARDS = ["bloom.lb.level", "bloom.lb.gathered", "bloom.lb.springs"]

# id -> (points, sprite for the badge). Order and ids follow BloomAchievements.all.
ACHIEVEMENTS = {
    "first_tree": (10, "bloom_tree"), "lumberjack": (40, "bloom_pine"), "miner": (40, "bloom_rock"),
    "berry": (30, "bloom_bush_berry"), "fisher": (40, "bloom_pond"), "furnace": (10, "bloom_furnace_0"),
    "builder": (50, "bloom_observatory"), "islands3": (20, "bloom_sign"), "islands6": (40, "bloom_sign"),
    "islands12": (60, "bloom_item_lantern"), "level10": (20, "bloom_ui_tree"), "level25": (40, "bloom_ui_tree"),
    "level50": (60, "bloom_ui_tree"), "helpers3": (30, "bloom_helper_sun_idle_0"), "gold_pick": (40, "bloom_pick_3"),
    "obsidian_pick": (50, "bloom_pick_5"), "chests": (40, "bloom_chest_closed"), "album": (60, "bloom_ui_book"),
    "spring": (40, "bloom_ui_spring"), "spring5": (60, "bloom_item_seed"), "week": (30, "bloom_ui_calendar"),
    "event": (40, "bloom_ui_event"), "lantern": (50, "bloom_item_lantern"),
}
assert sum(p for p, _ in ACHIEVEMENTS.values()) <= 1000


def badge(sprite):
    """512x512 PNG: the sprite, pixel-scaled, on a round gold-rimmed plate."""
    from PIL import Image, ImageDraw
    src = Image.open(os.path.join(ASSETS, sprite + ".imageset", sprite + ".png")).convert("RGBA")
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((8, 8, 504, 504), fill=(132, 196, 236, 255), outline=(255, 208, 64, 255), width=20)
    d.ellipse((28, 28, 484, 484), outline=(43, 32, 66, 255), width=6)
    k = max(1, min(300 // src.width, 300 // src.height))
    big = src.resize((src.width * k, src.height * k), Image.NEAREST)
    im.alpha_composite(big, ((512 - big.width) // 2, (512 - big.height) // 2))
    out = io.BytesIO(); im.save(out, "PNG")
    return out.getvalue()


def upload(c, kind, rel, rel_type, rel_id, data, name):
    """Reserve -> upload parts -> commit (the ASC asset flow)."""
    j = c.req("POST", f"/v1/{kind}", {"data": {"type": kind, "attributes": {"fileName": name, "fileSize": len(data)},
              "relationships": {rel: {"data": {"type": rel_type, "id": rel_id}}}}})
    if c.dry:
        return
    img = j["data"]
    for op in img["attributes"].get("uploadOperations") or []:
        part = data[op["offset"]:op["offset"] + op["length"]]
        hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        r = c.s.request(op["method"], op["url"], data=part, headers=hdr)
        if r.status_code >= 400:
            raise SystemExit(f"upload {name} -> {r.status_code} {r.text[:300]}")
    c.req("PATCH", f"/v1/{kind}/{img['id']}", {"data": {"type": kind, "id": img["id"], "attributes": {"uploaded": True}}})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    c = ASC(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"], a.dry_run)
    app = c.req("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"][0]
    app_id = app["id"]
    print("app", app["attributes"]["name"], app_id)

    try:
        gcd = c.req("GET", f"/v1/apps/{app_id}/gameCenterDetail").get("data")
    except SystemExit:
        gcd = None
    if not gcd:
        gcd = c.req("POST", "/v1/gameCenterDetails", {"data": {"type": "gameCenterDetails",
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        print("game center enabled", gcd["id"])
    gid = gcd["id"]

    have_lb = {} if c.dry else {x["attributes"]["vendorIdentifier"]: x["id"]
                                for x in c.all(f"/v1/gameCenterDetails/{gid}/gameCenterLeaderboards")}
    for vid in LEADERBOARDS:
        if vid in have_lb:
            print("leaderboard exists", vid); continue
        lid = c.req("POST", "/v1/gameCenterLeaderboards", {"data": {"type": "gameCenterLeaderboards", "attributes": {
            "referenceName": vid.split(".")[-1].title(), "vendorIdentifier": vid, "defaultFormatter": "INTEGER",
            "submissionType": "BEST_SCORE", "scoreSortType": "DESC"},
            "relationships": {"gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": gid}}}}})["data"]["id"]
        for locale, name in LB_L[vid]:
            c.req("POST", "/v1/gameCenterLeaderboardLocalizations", {"data": {"type": "gameCenterLeaderboardLocalizations",
                  "attributes": {"locale": locale, "name": name},
                  "relationships": {"gameCenterLeaderboard": {"data": {"type": "gameCenterLeaderboards", "id": lid}}}}})
        print("leaderboard +", vid)

    have_ach = {} if c.dry else {x["attributes"]["vendorIdentifier"]: x["id"]
                                 for x in c.all(f"/v1/gameCenterDetails/{gid}/gameCenterAchievements")}
    for aid, (pts, sprite) in ACHIEVEMENTS.items():
        vid = "bloom.ach." + aid
        if vid in have_ach:
            print("achievement exists", vid); continue
        xid = c.req("POST", "/v1/gameCenterAchievements", {"data": {"type": "gameCenterAchievements", "attributes": {
            "referenceName": aid, "vendorIdentifier": vid, "points": pts, "showBeforeEarned": True, "repeatable": False},
            "relationships": {"gameCenterDetail": {"data": {"type": "gameCenterDetails", "id": gid}}}}})["data"]["id"]
        png = badge(sprite)
        for locale, name, before, after in ACH_L[aid]:
            loc = c.req("POST", "/v1/gameCenterAchievementLocalizations", {"data": {
                "type": "gameCenterAchievementLocalizations",
                "attributes": {"locale": locale, "name": name, "beforeEarnedDescription": before, "afterEarnedDescription": after},
                "relationships": {"gameCenterAchievement": {"data": {"type": "gameCenterAchievements", "id": xid}}}}})["data"]["id"]
            upload(c, "gameCenterAchievementImages", "gameCenterAchievementLocalization",
                   "gameCenterAchievementLocalizations", loc, png, aid + ".png")
        print("achievement +", vid, pts)
    print("done")


if __name__ == "__main__":
    main()

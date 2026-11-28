#!/usr/bin/env python3
"""Create the Bloom shop products in App Store Connect (idempotent).

    pip3 install --user pyjwt cryptography requests
    ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXX.p8 \
        python3 tools/asc_iap.py [--dry-run]

The key never goes into the repo. Products already in App Store Connect are
left alone (only missing localizations / price / availability are filled in).
"""
import argparse
import hashlib, json, os, sys, time

import jwt
import requests

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from iap_locales import table as locale_table  # noqa: E402

API = "https://api.appstoreconnect.apple.com"
REVIEW_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "store", "review")
BUNDLE_ID = "game.dustbloom.app"

BUNDLES = {"bloom.brave", "bloom.crafter", "bloom.digger", "bloom.islandpack", "bloom.friend", "bloom.level10", "bloom.level20"}

# productId, type, USD price, reference name, ru (name, description), en (name, description)
PRODUCTS = [
    ("bloom.founder", "NON_CONSUMABLE", "4.99", "Founder Pack",
     ("Набор основателя", "Золотой блумлинг, рост +30% и 300 росинок"),
     ("Founder Pack", "Golden Bloomling, +30% regrowth, 300 dew")),
    ("bloom.pass28", "NON_RENEWING_SUBSCRIPTION", "7.99", "Bloom Pass 28 days",
     ("Пропуск цветения", "+25% добычи и опыта на 28 дней"),
     ("Bloom Pass", "+25% loot and XP for 28 days")),
    ("bloom.jar", "CONSUMABLE", "2.99", "Dew Jar",
     ("Банка росы", "Все росинки, накопленные в банке"),
     ("Dew Jar", "All the dew saved up in the jar")),
    ("bloom.gems.80", "CONSUMABLE", "0.99", "80 Dew",
     ("80 росинок", "Горсть росинок для лавки"),
     ("80 Dew", "A handful of dew for the shop")),
    ("bloom.gems.450", "CONSUMABLE", "4.99", "450 Dew",
     ("450 росинок", "Мешочек росинок для лавки"),
     ("450 Dew", "A pouch of dew for the shop")),
    ("bloom.gems.1000", "CONSUMABLE", "9.99", "1000 Dew",
     ("1000 росинок", "Кувшин росинок для лавки"),
     ("1000 Dew", "A jug of dew for the shop")),
    ("bloom.gems.2200", "CONSUMABLE", "19.99", "2200 Dew",
     ("2200 росинок", "Целое озеро росинок, самая выгодная цена"),
     ("2200 Dew", "A whole lake of dew, best value")),
    ("bloom.starter", "NON_CONSUMABLE", "0.99", "Starter Pack",
     ("Стартовый набор", "150 росинок, сундук и мятный облик"),
     ("Starter Pack", "150 dew, a chest and the Mint look")),
    ("bloom.slot", "NON_CONSUMABLE", "1.99", "Nursery Slot",
     ("Место в питомнике", "Ещё один блумлинг-помощник навсегда"),
     ("Nursery Slot", "One more Bloomling helper, forever")),
    ("bloom.eventpass", "CONSUMABLE", "2.99", "Event Pass",
     ("Пропуск события", "Все награды события этой недели"),
     ("Event Pass", "All rewards of this week's event")),
    # donate 2: bundles (shop "Bundles" section, also offered by a glowing button at the right moment)
    ("bloom.brave", "NON_CONSUMABLE", "1.99", "Brave Heart", None, None),
    ("bloom.crafter", "NON_CONSUMABLE", "4.99", "Jack of All Trades", None, None),
    ("bloom.digger", "NON_CONSUMABLE", "2.99", "Treasure Hunter", None, None),
    ("bloom.islandpack", "CONSUMABLE", "2.99", "Island Within Reach", None, None),
    ("bloom.friend", "NON_CONSUMABLE", "3.99", "Island Friend", None, None),
    ("bloom.level10", "NON_CONSUMABLE", "4.99", "Level 10 Bundle", None, None),
    ("bloom.level20", "NON_CONSUMABLE", "9.99", "Level 20 Bundle", None, None),
]


class ASC:
    def __init__(self, key_id, issuer, key_path, dry):
        self.key_id, self.issuer, self.dry = key_id, issuer, dry
        self.key = open(os.path.expanduser(key_path)).read()
        self.s = requests.Session()

    def token(self):
        now = int(time.time())
        return jwt.encode({"iss": self.issuer, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                          self.key, algorithm="ES256", headers={"kid": self.key_id, "typ": "JWT"})

    def req(self, method, path, body=None, params=None):
        if self.dry and method != "GET":
            print("  [dry-run]", method, path, json.dumps(body)[:200] if body else "")
            return {"data": {"id": "DRY"}}
        r = self.s.request(method, API + path, params=params, json=body,
                           headers={"Authorization": "Bearer " + self.token()})
        if r.status_code >= 400:
            raise SystemExit(f"{method} {path} -> {r.status_code}\n{r.text[:8000]}")
        return r.json() if r.text else {}

    def all(self, path, params=None):
        out, url, params = [], path, dict(params or {}, limit=200)
        while url:
            j = self.req("GET", url, params=params)
            out += j.get("data", [])
            nxt = j.get("links", {}).get("next")
            url, params = (nxt.replace(API, ""), None) if nxt else (None, None)
        return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    c = ASC(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"], a.dry_run)

    apps = c.req("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        raise SystemExit("app with bundle id %s not found" % BUNDLE_ID)
    app_id = apps[0]["id"]
    print("app", apps[0]["attributes"]["name"], app_id)

    global LOCALES
    LOCALES = locale_table()
    existing = {p["attributes"]["productId"]: p for p in c.all(f"/v1/apps/{app_id}/inAppPurchasesV2")}
    territories = [t["id"] for t in c.all("/v1/territories")]

    for pid, kind, usd, ref, ru, en in PRODUCTS:
        print("\n==", pid, kind, usd)
        if pid in existing:
            iap_id = existing[pid]["id"]
            print("  exists", iap_id, existing[pid]["attributes"].get("state"))
        else:
            iap_id = c.req("POST", "/v2/inAppPurchases", {"data": {
                "type": "inAppPurchases",
                "attributes": {"name": ref, "productId": pid, "inAppPurchaseType": kind,
                               "reviewNote": ("Shop (gift button, top right) -> section Bundles -> price button. "
                                              "It is also offered by a glowing button under the shop button.")
                               if pid in BUNDLES else
                               "Bought in the in-game shop (gift button, top right). "
                               "Test: open the shop and tap the price button."},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]["id"]
            print("  created", iap_id)

        # localizations
        have = {}
        if iap_id != "DRY":
            have = {l["attributes"]["locale"]: l for l in c.all(f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")}
        for locale, name, desc in LOCALES[pid]:
            if locale in have:
                cur = have[locale]["attributes"]
                if cur.get("name") != name[:30] or cur.get("description") != desc[:45]:
                    lid = have[locale]["id"]
                    c.req("PATCH", f"/v1/inAppPurchaseLocalizations/{lid}", {"data": {
                        "type": "inAppPurchaseLocalizations", "id": lid,
                        "attributes": {"name": name[:30], "description": desc[:45]}}})
                    print("  ~", locale)
                continue
            c.req("POST", "/v1/inAppPurchaseLocalizations", {"data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {"locale": locale, "name": name[:30], "description": desc[:45]},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})
            print("  +", locale)

        if iap_id == "DRY":
            continue
        # price: USA base territory, others follow Apple's equalization
        try:
            sched = c.req("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule")
            has_price = bool(sched.get("data"))
        except SystemExit:
            has_price = False
        if not has_price:
            pts = c.all(f"/v2/inAppPurchases/{iap_id}/pricePoints", {"filter[territory]": "USA"})
            pp = next((p for p in pts if p["attributes"]["customerPrice"] in (usd, usd + "0")), None)
            if not pp:
                raise SystemExit(f"no USA price point {usd} for {pid}")
            c.req("POST", "/v1/inAppPurchasePriceSchedules", {
                "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p0}"}]}}},
                "included": [{"type": "inAppPurchasePrices", "id": "${p0}",
                              "attributes": {"startDate": None},
                              "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp["id"]}}}}]})
            print("  price", usd)
        # availability: every territory, and new ones automatically
        try:
            av = c.req("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability")
            has_av = bool(av.get("data"))
        except SystemExit:
            has_av = False
        if not has_av:
            c.req("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
                "type": "inAppPurchaseAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                    "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]}}}})
            print("  available in", len(territories), "territories")
        # review screenshot: where the purchase appears in the game
        try:
            shot = c.req("GET", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot").get("data")
        except SystemExit:
            shot = None
        if not shot:
            name = "event.png" if pid == "bloom.eventpass" else "shop.png"
            if pid in BUNDLES and os.path.exists(os.path.join(REVIEW_DIR, "bundles.png")):
                name = "bundles.png"
            data = open(os.path.join(REVIEW_DIR, name), "rb").read()
            j = c.req("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
                "type": "inAppPurchaseAppStoreReviewScreenshots",
                "attributes": {"fileName": name, "fileSize": len(data)},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})["data"]
            for op in j["attributes"].get("uploadOperations") or []:
                hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
                r = c.s.request(op["method"], op["url"], data=data[op["offset"]:op["offset"] + op["length"]], headers=hdr)
                if r.status_code >= 400:
                    raise SystemExit(f"upload {name} -> {r.status_code} {r.text[:300]}")
            c.req("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{j['id']}", {"data": {
                "type": "inAppPurchaseAppStoreReviewScreenshots", "id": j["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
            print("  review screenshot", name)

    print("\ndone.")


if __name__ == "__main__":
    main()

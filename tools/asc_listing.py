#!/usr/bin/env python3
"""Fill the App Store page of version 1.0.0 in App Store Connect (idempotent).

Texts come from store/listing.py, screenshots from store/screenshots/<lang>/*.png
(6.9-inch, 1320x2868) and the app preview from store/preview/preview_en.mp4.
Also sets the category, the age rating answers and the copyright.

    ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=... python3 tools/asc_listing.py [--dry-run] [--no-media]
"""
import argparse
import glob
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "store"))
from asc_iap import ASC, BUNDLE_ID  # noqa: E402
import listing  # noqa: E402

VERSION = "1.0.0"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
REVIEW_NOTES = ("No login needed. The shop is the shop button in the right column of the HUD. "
                "Purchases: Founder Pack, Starter Pack and Nursery Slot (non-consumable), Bloom Pass "
                "(28-day non-renewing), Event Pass, Dew Jar and dew packs (consumables). "
                "\"Restore purchases\" is at the bottom of the shop. The game plays offline.")


def soft(c, method, path, body=None):
    """A request whose failure is reported but doesn't stop the run."""
    try:
        return c.req(method, path, body)
    except SystemExit as e:
        print("  ! skipped:", str(e).splitlines()[0])
        print("   ", str(e)[len(str(e).splitlines()[0]):][:600].strip())
        return None


def upload(c, kind, attrs, rel_name, rel_type, rel_id, data, name):
    j = c.req("POST", f"/v1/{kind}", {"data": {
        "type": kind, "attributes": dict(attrs, fileName=name, fileSize=len(data)),
        "relationships": {rel_name: {"data": {"type": rel_type, "id": rel_id}}}}})["data"]
    if j["id"] == "DRY":
        return
    for op in j["attributes"].get("uploadOperations") or []:
        hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        r = c.s.request(op["method"], op["url"], data=data[op["offset"]:op["offset"] + op["length"]], headers=hdr)
        if r.status_code >= 400:
            raise SystemExit(f"upload {name} -> {r.status_code} {r.text[:300]}")
    c.req("PATCH", f"/v1/{kind}/{j['id']}", {"data": {
        "type": kind, "id": j["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-media", action="store_true")
    a = ap.parse_args()
    bad = listing.check()
    if bad:
        raise SystemExit(f"texts over the limits: {bad}")
    c = ASC(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"], a.dry_run)

    app = c.req("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"][0]
    app_id = app["id"]
    print("app", app["attributes"]["name"], app_id, "primary locale", app["attributes"].get("primaryLocale"))

    # ---- version 1.0.0
    versions = c.all(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"})
    v = next((x for x in versions if x["attributes"]["appStoreState"] in EDITABLE), None)
    if v is None:
        v = c.req("POST", "/v1/appStoreVersions", {"data": {
            "type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": VERSION},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        print("created version", VERSION)
    vid = v["id"]
    attrs = {"copyright": listing.COPYRIGHT}
    if v.get("attributes", {}).get("versionString") not in (None, VERSION):
        attrs["versionString"] = VERSION
    print("version", v.get("attributes", {}).get("versionString"), "->", VERSION, v.get("attributes", {}).get("appStoreState"))
    soft(c, "PATCH", f"/v1/appStoreVersions/{vid}", {"data": {"type": "appStoreVersions", "id": vid, "attributes": attrs}})

    # ---- app info: category, age rating, names
    infos = c.all(f"/v1/apps/{app_id}/appInfos")
    info = next((i for i in infos if i["attributes"].get("appStoreState", i["attributes"].get("state")) not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION")), infos[0])
    iid = info["id"]
    print("\ncategory Games / Casual + Simulation")
    soft(c, "PATCH", f"/v1/appInfos/{iid}", {"data": {"type": "appInfos", "id": iid, "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
        "primarySubcategoryOne": {"data": {"type": "appCategories", "id": "GAMES_CASUAL"}},
        "primarySubcategoryTwo": {"data": {"type": "appCategories", "id": "GAMES_SIMULATION"}}}}})

    print("age rating")
    ar = soft(c, "GET", f"/v1/appInfos/{iid}/ageRatingDeclaration")
    if ar and ar.get("data"):
        ar_id, cur = ar["data"]["id"], ar["data"]["attributes"]
        # cartoon pickaxe swings at rocks and trees only; rewarded ads; no chat, no web, no real gambling
        yes = {"advertising"}
        keep = {"lootBox", "kidsAgeBand", "ageRatingOverride", "ageRatingOverrideV2", "koreaAgeRatingOverride",
                "developerAgeRatingInfoUrl"}
        new = {}
        for k, val in cur.items():
            if k in keep:
                continue
            if isinstance(val, bool) or (val is None and k in yes | {"gambling", "unrestrictedWebAccess", "messagingAndChat",
                                                                     "userGeneratedContent", "parentalControls", "ageAssurance",
                                                                     "healthOrWellnessTopics"}):
                new[k] = k in yes
            elif isinstance(val, str) or val is None:
                new[k] = "NONE"
        print("  ", new)
        soft(c, "PATCH", f"/v1/ageRatingDeclarations/{ar_id}", {"data": {"type": "ageRatingDeclarations", "id": ar_id, "attributes": new}})
        print("   loot box answer left as is:", cur.get("lootBox"))

    print("\napp info localizations")
    have_info = {l["attributes"]["locale"]: l for l in c.all(f"/v1/appInfos/{iid}/appInfoLocalizations")}
    for lang, loc in listing.ASC_LOCALE.items():
        d = listing.L[lang]
        at = {"name": listing.NAME, "subtitle": d["subtitle"], "privacyPolicyUrl": listing.PRIVACY_URL}
        if loc in have_info:
            lid = have_info[loc]["id"]
            soft(c, "PATCH", f"/v1/appInfoLocalizations/{lid}", {"data": {"type": "appInfoLocalizations", "id": lid, "attributes": at}})
        else:
            soft(c, "POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": dict(at, locale=loc),
                 "relationships": {"appInfo": {"data": {"type": "appInfos", "id": iid}}}}})
        print("  ", loc)

    # ---- version localizations, screenshots, preview
    print("\nversion localizations")
    have = {l["attributes"]["locale"]: l for l in c.all(f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")} if vid != "DRY" else {}
    for lang, loc in listing.ASC_LOCALE.items():
        d = listing.L[lang]
        at = {"description": d["desc"], "keywords": d["keywords"], "promotionalText": d["promo"], "supportUrl": listing.SUPPORT_URL}
        if loc in have:
            lid = have[loc]["id"]
            soft(c, "PATCH", f"/v1/appStoreVersionLocalizations/{lid}", {"data": {"type": "appStoreVersionLocalizations", "id": lid, "attributes": at}})
        else:
            r = soft(c, "POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations",
                     "attributes": dict(at, locale=loc), "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
            lid = r["data"]["id"] if r else None
        print("  ", loc, "text")
        if a.no_media or not lid or lid == "DRY":
            continue

        shots = sorted(glob.glob(os.path.join(ROOT, "store", "screenshots", lang, "*.png")))
        sets = c.all(f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets")
        sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
        if sset is None:
            sset = c.req("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                         "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                         "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}})["data"]
        for old in c.all(f"/v1/appScreenshotSets/{sset['id']}/appScreenshots"):
            c.req("DELETE", f"/v1/appScreenshots/{old['id']}")
        for p in shots:
            upload(c, "appScreenshots", {}, "appScreenshotSet", "appScreenshotSets", sset["id"], open(p, "rb").read(), os.path.basename(p))
        print("  ", loc, len(shots), "screenshots")

        if lang == "en":
            prev = os.path.join(ROOT, "store", "preview", "preview_en.mp4")
            psets = c.all(f"/v1/appStoreVersionLocalizations/{lid}/appPreviewSets")
            pset = next((s for s in psets if s["attributes"]["previewType"] == "IPHONE_67"), None)
            if pset is None:
                pset = c.req("POST", "/v1/appPreviewSets", {"data": {"type": "appPreviewSets", "attributes": {"previewType": "IPHONE_67"},
                             "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}})["data"]
            for old in c.all(f"/v1/appPreviewSets/{pset['id']}/appPreviews"):
                c.req("DELETE", f"/v1/appPreviews/{old['id']}")
            upload(c, "appPreviews", {"mimeType": "video/mp4", "previewFrameTimeCode": "00:00:05:00"},
                   "appPreviewSet", "appPreviewSets", pset["id"], open(prev, "rb").read(), "preview_en.mp4")
            print("   en-US preview")

    # ---- review notes (contact details stay for the owner to fill in by hand)
    print("\nreview notes")
    rd = soft(c, "GET", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
    if rd and rd.get("data"):
        rid = rd["data"]["id"]
        soft(c, "PATCH", f"/v1/appStoreReviewDetails/{rid}", {"data": {"type": "appStoreReviewDetails", "id": rid,
             "attributes": {"notes": REVIEW_NOTES, "demoAccountRequired": False}}})
    else:
        soft(c, "POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails",
             "attributes": {"notes": REVIEW_NOTES, "demoAccountRequired": False},
             "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    print("\ndone.")


if __name__ == "__main__":
    main()

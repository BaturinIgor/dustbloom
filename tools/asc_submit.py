#!/usr/bin/env python3
"""Attach the newest processed build to version 1.0.0, add the in-app purchases and
Game Center to it, and send the version to App Review.

    ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=... python3 tools/asc_submit.py [--dry-run] [--build 202611272314]

With --dry-run nothing is changed: it prints what is missing instead.
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_iap import ASC, BUNDLE_ID  # noqa: E402

EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
OPEN_SUBMISSION = {"READY_FOR_REVIEW", "UNRESOLVED_ISSUES"}


def soft(c, method, path, body=None, params=None):
    try:
        return c.req(method, path, body, params)
    except SystemExit as e:
        print("  ! ", str(e)[:3000])
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--build", default="")
    ap.add_argument("--wait", type=int, default=35, help="minutes to wait for the build to finish processing")
    a = ap.parse_args()
    c = ASC(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"], a.dry_run)

    app = c.req("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"][0]
    app_id = app["id"]
    print("app", app["attributes"]["name"], app_id)

    # content rights: original art, synthesized music, CC0 sounds
    if not app["attributes"].get("contentRightsDeclaration"):
        print("content rights -> does not use third-party content")
        soft(c, "PATCH", f"/v1/apps/{app_id}", {"data": {"type": "apps", "id": app_id,
             "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})

    # price: the game is free
    ps = soft(c, "GET", f"/v1/apps/{app_id}/appPriceSchedule")
    if not (ps and ps.get("data")):
        print("price -> free")
        pts = c.all(f"/v1/apps/{app_id}/appPricePoints", {"filter[territory]": "USA"})
        free = next((p for p in pts if float(p["attributes"]["customerPrice"]) == 0), None)
        if free:
            soft(c, "POST", "/v1/appPriceSchedules", {
                "data": {"type": "appPriceSchedules", "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "appPrices", "id": "${p0}"}]}}},
                "included": [{"type": "appPrices", "id": "${p0}", "attributes": {"startDate": None},
                              "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
    else:
        print("price set")
    av = soft(c, "GET", f"/v1/apps/{app_id}/appAvailabilityV2")
    print("availability", "set" if av and av.get("data") else "MISSING (set it in Pricing and Availability)")

    # version
    versions = c.all(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"})
    v = next((x for x in versions if x["attributes"]["appStoreState"] in EDITABLE), None)
    if v is None:
        print("no editable version:", [(x["attributes"]["versionString"], x["attributes"]["appStoreState"]) for x in versions])
        return
    vid = v["id"]
    print("version", v["attributes"]["versionString"], v["attributes"]["appStoreState"])

    # build: wait until Apple has processed it
    params = {"filter[app]": app_id, "sort": "-uploadedDate", "limit": 5}
    if a.build:
        params["filter[version]"] = a.build
    build = None
    for i in range(a.wait * 2 + 1):
        builds = c.req("GET", "/v1/builds", params=params).get("data", [])
        if builds:
            b = builds[0]
            st = b["attributes"]["processingState"]
            print(f"  build {b['attributes']['version']} {st}")
            if st == "VALID":
                build = b
                break
            if st in ("FAILED", "INVALID"):
                raise SystemExit("build processing failed")
        else:
            print("  build not visible yet")
        time.sleep(30)
    if not build:
        raise SystemExit("build is still processing; run again later")
    bid = build["id"]
    if build["attributes"].get("usesNonExemptEncryption") is None:
        soft(c, "PATCH", f"/v1/builds/{bid}", {"data": {"type": "builds", "id": bid,
             "attributes": {"usesNonExemptEncryption": False}}})
    print("attach build", build["attributes"]["version"])
    soft(c, "PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": bid}})

    # in-app purchases go to review together with the version
    print("\nin-app purchases")
    for p in c.all(f"/v1/apps/{app_id}/inAppPurchasesV2"):
        st = p["attributes"].get("state")
        print("  ", p["attributes"]["productId"], st)
        if st == "READY_TO_SUBMIT":
            soft(c, "POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions",
                 "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": p["id"]}}}}})

    # Game Center on this version (leaderboards and achievements ship with it)
    print("\ngame center")
    gv = soft(c, "GET", f"/v1/appStoreVersions/{vid}/gameCenterAppVersion")
    if gv and gv.get("data"):
        print("   already on the version")
    else:
        soft(c, "POST", "/v1/gameCenterAppVersions", {"data": {"type": "gameCenterAppVersions",
             "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})

    # review submission
    print("\nreview submission")
    subs = c.all("/v1/reviewSubmissions", {"filter[app]": app_id, "filter[platform]": "IOS"})
    sub = next((s for s in subs if s["attributes"].get("state") in OPEN_SUBMISSION), None)
    if sub is None:
        sub = c.req("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
    sid = sub["id"]
    items = c.all(f"/v1/reviewSubmissions/{sid}/items") if sid != "DRY" else []
    if not any(i.get("relationships", {}).get("appStoreVersion", {}).get("data") for i in items):
        soft(c, "POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
             "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
                               "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    r = soft(c, "PATCH", f"/v1/reviewSubmissions/{sid}", {"data": {"type": "reviewSubmissions", "id": sid,
             "attributes": {"submitted": True}}})
    if r and r.get("data"):
        print("\nSUBMITTED, state:", r["data"]["attributes"].get("state"))
    else:
        print("\nnot submitted, see the errors above")
        sys.exit(1)


if __name__ == "__main__":
    main()

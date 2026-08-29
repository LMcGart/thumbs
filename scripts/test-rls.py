#!/usr/bin/env python3
"""Item 4 done-when check: two anonymous users; A rates a place; B must not
see it until friended, then must. Reads Config.xcconfig for URL + anon key.
Run: python3 scripts/test-rls.py"""
import json
import pathlib
import sys
import urllib.request

root = pathlib.Path(__file__).resolve().parent.parent
config = {}
for line in (root / "Config.xcconfig").read_text().splitlines():
    if "=" in line and not line.strip().startswith("//"):
        key, _, value = line.partition("=")
        config[key.strip()] = value.strip().replace("$()", "")
URL = config["SUPABASE_URL"].rstrip("/")
KEY = config["SUPABASE_ANON_KEY"]
if "YOUR-" in URL or "YOUR-" in KEY:
    sys.exit("Fill in Config.xcconfig first")

def call(method, path, token=None, body=None, prefer=None):
    request = urllib.request.Request(URL + path, method=method)
    request.add_header("apikey", KEY)
    request.add_header("Authorization", f"Bearer {token or KEY}")
    request.add_header("Content-Type", "application/json")
    if prefer:
        request.add_header("Prefer", prefer)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(request, data) as response:
            text = response.read().decode()
            return json.loads(text) if text else None
    except urllib.error.HTTPError as error:
        sys.exit(f"FAIL {method} {path}: {error.code} {error.read().decode()[:300]}")

checks = []
def check(name, ok):
    checks.append(ok)
    print(("PASS" if ok else "FAIL"), name)

a = call("POST", "/auth/v1/signup", body={})
b = call("POST", "/auth/v1/signup", body={})
token_a, id_a = a["access_token"], a["user"]["id"]
token_b, id_b = b["access_token"], b["user"]["id"]
print(f"user A {id_a[:8]}… · user B {id_b[:8]}…")

places = call("GET", "/rest/v1/places?select=id,name&limit=1", token_a)
check("seeded places visible", bool(places))
place = places[0]

visit = call("POST", "/rest/v1/visits", token_a,
             body={"user_id": id_a, "place_id": place["id"],
                   "visited_at": "2026-08-29T19:00:00Z", "source": "manual"},
             prefer="return=representation")[0]
call("POST", "/rest/v1/ratings", token_a,
     body={"visit_id": visit["id"], "score": 7, "category": "restaurant"})
mine = call("GET", "/rest/v1/ratings?select=id", token_a)
check(f"A rated {place['name']!r} and reads it back", len(mine) == 1)

check("B sees no ratings before friendship",
      len(call("GET", "/rest/v1/ratings?select=id", token_b)) == 0)
check("B sees no visits before friendship",
      len(call("GET", "/rest/v1/visits?select=id", token_b)) == 0)

call("POST", "/rest/v1/friendships", token_a,
     body={"requester": id_a, "addressee": id_b, "status": "requested"})
check("B still sees nothing while request pending",
      len(call("GET", "/rest/v1/ratings?select=id", token_b)) == 0)

call("PATCH", f"/rest/v1/friendships?requester=eq.{id_a}&addressee=eq.{id_b}",
     token_b, body={"status": "accepted"})
check("B sees A's rating after accepting",
      len(call("GET", "/rest/v1/ratings?select=id", token_b)) == 1)
check("B sees A's visit after accepting",
      len(call("GET", "/rest/v1/visits?select=id", token_b)) == 1)

# B must not be able to write as A.
request_failed = False
try:
    call("POST", "/rest/v1/visits", token_b,
         body={"user_id": id_a, "place_id": place["id"],
               "visited_at": "2026-08-29T20:00:00Z", "source": "manual"})
except SystemExit:
    request_failed = True
check("B cannot insert a visit as A", request_failed)

print("\nAll passed" if all(checks) else "\nFAILURES above")
sys.exit(0 if all(checks) else 1)

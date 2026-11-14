#!/usr/bin/env python3
"""Offline replica of the TP-05A-05A water temperature foundation (stdlib only, not used by the game).
Mirrors scripts/systems/water_temperature_data.gd, flat_water_surface_provider.gd,
water_temperature_provider.gd (sample point) and island.gd height function.
It checks the FORMULAS and decision logic only; it is not a Godot runtime test.
Usage: python3 -I tools/water_temperature_sim.py"""
import math, random

NAN = float("nan")
fin = math.isfinite

# ---- Inspector defaults (keep in sync with the .gd files) -----------------
P = dict(surface=26.0, deep=14.0, scale=25.0, max_depth=200.0, tmin=-2.0, tmax=40.0)
SURF_Y = 0.0
EXTENT = (-500.0, -500.0, 1000.0, 1000.0)   # x, z, w, h
SAMPLE_H = 0.9

def clampf(v, lo, hi): return max(lo, min(hi, v))

def bad(v): return not fin(v)

def settings_problem(p=P):  # WaterTemperatureData._settings_problem
    if bad(p["surface"]): return "surface_temperature"
    if bad(p["deep"]): return "deep_temperature"
    if bad(p["scale"]) or p["scale"] <= 0: return "depth_scale"
    if bad(p["max_depth"]) or p["max_depth"] < 0: return "max_depth"
    if bad(p["tmin"]) or bad(p["tmax"]): return "min/max_nan"
    if p["tmin"] > p["tmax"]: return "min>max"
    return ""

def temp_at_depth(depth, p=P, region_offset=0.0, temporal=0.0):  # get_temperature_at_depth
    if settings_problem(p) or bad(depth): return NAN
    if bad(region_offset) or bad(temporal): return NAN
    surf = p["surface"] + region_offset + temporal
    if bad(surf): return NAN
    d = clampf(depth, 0.0, p["max_depth"])
    mix = 1.0 - math.exp(-d / p["scale"])
    t = surf + (p["deep"] - surf) * mix
    if bad(t): return NAN
    return clampf(t, p["tmin"], p["tmax"])

def has_point(x, z):  # Rect2.has_point: right/bottom edges excluded
    ex, ez, w, h = EXTENT
    return ex <= x < ex + w and ez <= z < ez + h

def water_depth(pos, ground, require_ground=True, limit=True):  # FlatWaterSurfaceProvider
    x, y, z = pos
    if not (fin(x) and fin(y) and fin(z)) or not fin(SURF_Y): return NAN
    if limit and not has_point(x, z): return NAN
    if not fin(ground):
        if require_ground: return NAN
    elif y < ground: return NAN
    d = SURF_Y - y
    return NAN if d < 0 else d

HW, HD, PLATEAU, HILL, INLAND, OUTER, SEABED = 90.0, 70.0, 4.0, 1.4, 0.55, 1.01, -1.0
def island_h(x, z):  # island.gd _height_at
    nx, nz = x / HW, z / HD
    r = math.sqrt(nx * nx + nz * nz)
    if r > OUTER: return SEABED
    t = clampf((OUTER - r) / (OUTER - INLAND), 0.0, 1.0)
    s = t * t * (3 - 2 * t)
    hills = (math.sin(x * .045) * math.cos(z * .05) + .5 * math.sin(x * .09 + 1.3) * math.sin(z * .08)) * HILL * s
    return max(0.0, s * PLATEAU + hills)

def ground_y(x, z):  # WaterTemperatureData._ground_height_at (terrain at origin, no transform)
    ex, ez, w, h = (-90.0, -70.0, 180.0, 140.0)
    if not (ex <= x < ex + w and ez <= z < ez + h): return -1.0e6   # NO_GROUND_Y
    return island_h(x, z)

def query(player_pos, ground_known=True):  # provider + data.query_at
    p = (player_pos[0], player_pos[1] + SAMPLE_H, player_pos[2])
    g = ground_y(p[0], p[2]) if ground_known else NAN
    d = water_depth(p, g)
    if not fin(d): return None
    return dict(depth=d, temp=temp_at_depth(d))

fails = []
def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail else ""))
    if not ok: fails.append(name)

# 1. surface temperature follows the Inspector value
for s in (26.0, 18.5, -1.0, 35.0):
    q = dict(P, surface=s)
    check(f"1 surface={s} -> depth 0 equals it", temp_at_depth(0.0, q) == s, f"{temp_at_depth(0.0, q)}")
# 2. consistent change with depth (monotone toward deep, never past it), both directions
for sf, dp in ((26.0, 14.0), (10.0, 14.0)):
    q = dict(P, surface=sf, deep=dp)
    ds = [0, .1, .5, 1, 2, 5, 10, 25, 50, 100, 200, 1000]
    ts = [temp_at_depth(d, q) for d in ds]
    sign = 1 if dp > sf else -1
    mono = all(sign * (b - a) >= -1e-12 for a, b in zip(ts, ts[1:]))
    bounded = all(min(sf, dp) - 1e-9 <= t <= max(sf, dp) + 1e-9 for t in ts)
    check(f"2 monotone toward deep ({sf}->{dp})", mono and bounded, " ".join(f"{t:.2f}" for t in ts))
q = temp_at_depth(25.0); check("2 e-folding: depth=scale gives 63.2% of change", abs((26 - q) / 12 - (1 - math.exp(-1))) < 1e-9, f"{q:.3f}")
# 3. depth zero -> surface (also via full query with sample exactly at surface)
r = query((0, -SAMPLE_H, 200)); check("3 sample at surface -> depth 0, temp = surface", r and r["depth"] == 0 and r["temp"] == P["surface"], str(r))
# 4. outside water -> unavailable
cases = {
 "standing on island (y=ground)": ((0, island_h(0, 0), 0), True),
 "on the beach above surface": ((88, 0.0, 0), True),
 "in the air above ocean": ((200, 10, 0), True),
 "feet on ocean surface (sample 0.9 above)": ((200, 0.0, 0), True),
 "underground below island": ((0, -5.0, 0), True),
 "beyond ocean extent": ((600, -3.0, 0), True),
 "NaN position": ((NAN, -3.0, 0), True),
 "inf position": ((0, -math.inf, 0), True),
 "ground unknown (require_ground)": ((200, -3.0, 0), False),
}
for n, (pos, gk) in cases.items(): check(f"4 unavailable: {n}", query(pos, gk) is None)
check("4 available: swimming in open sea outside the island grid (feet -3)", query((200, -3.0, 0)) is not None)
check("4 available: standing on the seabed inside the grid (x=85,z=60, feet -1.0 -> sample -0.1)", query((85, -1.0, 60)) is not None)
check("4 unavailable: below the seabed collider inside the grid (x=85,z=60, feet -3)", query((85, -3.0, 60)) is None)
# 5. values always valid and bounded (fuzz, incl. extreme settings)
random.seed(5); nbad = 0; n_av = 0
for _ in range(200000):
    pos = (random.uniform(-700, 700), random.choice([random.uniform(-400, 40), 1e9, -1e9]), random.uniform(-700, 700))
    r = query(pos)
    if r:
        n_av += 1
        if not (fin(r["temp"]) and fin(r["depth"]) and r["depth"] >= 0 and P["tmin"] <= r["temp"] <= P["tmax"]): nbad += 1
check("5 fuzz: every available reading finite, depth>=0, in limits", nbad == 0 and n_av > 1000, f"{n_av} available of 200000, bad={nbad}")
INF = math.inf
# Fix 01: every invalid setting -> unavailable (NAN) with the right reason, at every depth
invalid = {
 "depth_scale 0": (dict(P, scale=0.0), "depth_scale"), "depth_scale negative": (dict(P, scale=-5.0), "depth_scale"),
 "depth_scale NaN": (dict(P, scale=NAN), "depth_scale"), "depth_scale inf": (dict(P, scale=INF), "depth_scale"),
 "max_depth negative": (dict(P, max_depth=-1.0), "max_depth"), "max_depth NaN": (dict(P, max_depth=NAN), "max_depth"),
 "max_depth inf": (dict(P, max_depth=INF), "max_depth"),
 "surface NaN": (dict(P, surface=NAN), "surface_temperature"), "surface inf": (dict(P, surface=INF), "surface_temperature"),
 "deep NaN": (dict(P, deep=NAN), "deep_temperature"), "deep -inf": (dict(P, deep=-INF), "deep_temperature"),
 "min NaN": (dict(P, tmin=NAN), "min/max_nan"), "max inf": (dict(P, tmax=INF), "min/max_nan"),
 "limits reversed (min 40, max -2)": (dict(P, tmin=40.0, tmax=-2.0), "min>max"),
}
for n, (q, why) in invalid.items():
    ok = settings_problem(q) == why and all(math.isnan(temp_at_depth(d, q)) for d in (0, 1, 200, 1e6))
    check(f"5 invalid -> unavailable: {n}", ok, settings_problem(q))
check("5 tmin == tmax is valid and pins the value", temp_at_depth(10, dict(P, tmin=20.0, tmax=20.0)) == 20.0)
check("5 max_depth 0 is valid: every depth gives the surface value", all(temp_at_depth(d, dict(P, max_depth=0.0)) == 26.0 for d in (0, 5, 1e6)))
check("5 tiny positive depth_scale stays finite and monotone", all(fin(temp_at_depth(d, dict(P, scale=1e-300))) for d in (0, 1e-300, 1, 200)) and temp_at_depth(0, dict(P, scale=1e-300)) == 26.0)
check("5 huge valid values: overflow -> unavailable, never inf", math.isnan(temp_at_depth(1, dict(P, surface=1.7e308, deep=-1.7e308, tmin=-1.7e308, tmax=1.7e308))))
check("5 valid but extreme surface is clamped into limits", temp_at_depth(0, dict(P, surface=1e6)) == 40.0 and temp_at_depth(0, dict(P, surface=-1e6)) == -2.0)
# depth zero and maximum depth with normal values
check("5 depth 0 = surface; depth=max_depth equals depth beyond it (clamp)", temp_at_depth(0) == 26.0 and temp_at_depth(200) == temp_at_depth(1e9) and temp_at_depth(200) > 13.99)
# final value always inside limits (random valid settings, random depths)
random.seed(9); okl = True
for _ in range(100000):
    q = dict(surface=random.uniform(-500, 500), deep=random.uniform(-500, 500), scale=10 ** random.uniform(-6, 4), max_depth=random.uniform(0, 1000), tmin=random.uniform(-50, 10), tmax=random.uniform(10, 80))
    d = random.uniform(0, 2000); t = temp_at_depth(d, q)
    okl &= fin(t) and q["tmin"] <= t <= q["tmax"]
check("7 random valid settings: result finite and within [min, max]", okl)
# monotone in depth for random valid settings (non-strict, toward deep, clamped)
okm = True
for _ in range(20000):
    q = dict(P, surface=random.uniform(-1, 39), deep=random.uniform(-1, 39), scale=10 ** random.uniform(-3, 3), max_depth=random.uniform(0, 500))
    ts = [temp_at_depth(d, q) for d in sorted(random.uniform(0, 600) for _ in range(12))]
    sg = 1 if q["deep"] >= q["surface"] else -1
    okm &= all(sg * (b2 - a2) >= -1e-9 for a2, b2 in zip(ts, ts[1:]))
check("6 random valid settings: monotone toward deep_temperature", okm)
# regions: offset only applies to surface; default region = base
check("regions: offset +3 raises surface by exactly 3", abs(temp_at_depth(0, P, 3.0) - 29.0) < 1e-12)
for n, off in (("NaN", NAN), ("inf", INF), ("-inf", -INF)):
    check(f"regions: invalid water_temperature_offset ({n}) -> unavailable", math.isnan(temp_at_depth(0, P, off)))
check("regions: finite offset that overflows the sum -> unavailable", math.isnan(temp_at_depth(0, dict(P, surface=1.7e308), 1.7e308)))
check("temporal hook: NaN offset -> unavailable", math.isnan(temp_at_depth(0, P, 0.0, NAN)))
# 6. independence: the water provider writes only water_profile_* fields (see static check); here: no shared state
print("6 provider independence is checked statically (tools/static_check_water.py)")
print("\nRESULT:", "ALL PASS" if not fails else f"{len(fails)} FAIL: {fails}")
raise SystemExit(1 if fails else 0)

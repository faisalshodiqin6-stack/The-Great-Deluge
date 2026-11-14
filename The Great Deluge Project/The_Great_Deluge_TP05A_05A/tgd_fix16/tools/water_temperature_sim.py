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

def temp_at_depth(depth, p=P, region_offset=0.0, temporal=0.0):
    surf = p["surface"] + region_offset + temporal
    if not fin(depth) or not fin(surf) or not fin(p["deep"]): return NAN
    d = clampf(depth, 0.0, max(p["max_depth"], 0.0))
    mix = 1.0 - math.exp(-d / max(p["scale"], 0.001))
    t = surf + (p["deep"] - surf) * mix
    lo, hi = min(p["tmin"], p["tmax"]), max(p["tmin"], p["tmax"])
    return clampf(t, lo, hi)

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
random.seed(5); bad = 0; n_av = 0
for _ in range(200000):
    pos = (random.uniform(-700, 700), random.choice([random.uniform(-400, 40), 1e9, -1e9]), random.uniform(-700, 700))
    r = query(pos)
    if r:
        n_av += 1
        if not (fin(r["temp"]) and fin(r["depth"]) and r["depth"] >= 0 and P["tmin"] <= r["temp"] <= P["tmax"]): bad += 1
check("5 fuzz: every available reading finite, depth>=0, in limits", bad == 0 and n_av > 1000, f"{n_av} available of 200000, bad={bad}")
extreme = [dict(P, surface=1e6), dict(P, surface=-1e6), dict(P, deep=1e9), dict(P, scale=0.0), dict(P, scale=-5.0), dict(P, max_depth=-1.0), dict(P, tmin=40, tmax=-2)]
ok = True
for q in extreme:
    for d in (0, 1, 1e6):
        t = temp_at_depth(d, q); lo, hi = min(q["tmin"], q["tmax"]), max(q["tmin"], q["tmax"])
        ok &= fin(t) and lo <= t <= hi
check("5 extreme settings stay finite and clamped", ok)
check("5 NaN setting -> NAN (provider reports unavailable, no invented value)", math.isnan(temp_at_depth(1.0, dict(P, surface=NAN))) and math.isnan(temp_at_depth(NAN)))
# regions: offset only applies to surface; default region = base
check("regions: offset +3 raises surface by exactly 3", abs(temp_at_depth(0, P, 3.0) - 29.0) < 1e-12)
# 6. independence: the water provider writes only water_profile_* fields (see static check); here: no shared state
print("6 provider independence is checked statically (tools/static_check_water.py)")
print("\nRESULT:", "ALL PASS" if not fails else f"{len(fails)} FAIL: {fails}")
raise SystemExit(1 if fails else 0)

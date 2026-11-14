#!/usr/bin/env python3
"""TP-05A-05B offline check: replica of BodyTemperature._integrate BEFORE (old) and AFTER (new) the
water-profile integration, fed with identical EnvironmentSamples. stdlib only, not used by the game.
Simulation of the formulas only; NOT a Godot parse or runtime test.
Usage: python3 -I tools/body_water_integration_sim.py"""
import math, random
NAN, INF = float("nan"), math.inf
fin = math.isfinite

# Defaults from body_temperature.gd (TP-05A-04F calibration state)
B = dict(normal=37.0, C=250000.0, basal=80.0, walk=150.0, sprint=450.0, swim=350.0, sweat=300.0,
         neutral=22.0, wind_k=0.1, water_mult=25.0, hum_pen=0.8, sun_w=300.0, tmin=25.0, tmax=44.0, max_sub=300.0)

def sample(**kw):
    s = dict(has_air=False, air=0.0, has_sun=False, sun=0.0, sun_above=False, has_wind=False, wind=0.0,
             has_hum=False, hum=0.0, has_water=False, in_water=False, water_t=0.0,
             has_shelter=False, sh_sun=0.0, sh_wind=0.0,
             has_profile=False, prof_t=0.0, prof_depth=0.0)
    s.update(kw); return s

def activity(act, p): return {"rest": 0.0, "walk": p["walk"], "sprint": p["sprint"], "swim": p["swim"]}[act]
def clampf(v, lo, hi): return max(lo, min(hi, v))

def _body(T, dt, s, act, p, in_water, env_override):
    air = s["air"] if s["has_air"] else p["neutral"]
    wind = s["wind"] if s["has_wind"] else 0.0
    sun = clampf(s["sun"], 0, 1) if (s["has_sun"] and s["sun_above"]) else 0.0
    wb = s["sh_wind"] if s["has_shelter"] else 0.0
    sb = s["sh_sun"] if s["has_shelter"] else 0.0
    env = env_override if in_water else air
    g = p["basal"] / max(p["normal"] - p["neutral"], 0.1)
    n_mult = 0
    if in_water: g *= p["water_mult"]; n_mult += 1
    else: g *= 1.0 + p["wind_k"] * wind * (1 - wb)
    prod = p["basal"] + activity(act, p)
    if not in_water: prod += p["sun_w"] * sun * (1 - sb)
    sw = 0.0
    if T > p["normal"] and not in_water:
        sw = p["sweat"] * (1.0 - (p["hum_pen"] * s["hum"] if s["has_hum"] else 0.0))
    tot = max(g + sw, 0.001)
    eq = (prod + g * env + sw * p["normal"]) / tot
    tau = p["C"] / tot
    return clampf(eq + (T - eq) * math.exp(-dt / tau), p["tmin"], p["tmax"]), n_mult, sw, prod

def integrate_old(T, dt, s, act, p=B):            # BEFORE: legacy flags only (no finiteness check)
    return _body(T, dt, s, act, p, s["has_water"] and s["in_water"], s["water_t"])[0]

def water_env(s):                                   # AFTER: BodyTemperature._water_environment_temperature
    if s["has_profile"] and fin(s["prof_t"]): return s["prof_t"]
    if s["has_water"] and s["in_water"] and fin(s["water_t"]): return s["water_t"]
    return NAN

def integrate_new(T, dt, s, act, p=B, detail=False):
    w = water_env(s); inw = not math.isnan(w)
    r = _body(T, dt, s, act, p, inw, w)
    return r if detail else r[0]

def advance(T, secs, s, act, fn, p=B):             # BodyTemperature.advance: substeps of max_substep_seconds
    rem, guard = secs, 0
    while rem > 1e-6 and guard < 4000:
        guard += 1; st = min(rem, max(p["max_sub"], 1.0)); T = fn(T, st, s, act, p); rem -= st
    return T

fails = []
def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail else ""))
    if not ok: fails.append(name)

AIR = sample(has_air=True, air=25.0)
# 1. AIR PATH: old == new, bit for bit, over random samples without any water data (and with legacy water)
random.seed(11); diff = 0; N = 60000
for i in range(N):
    legacy = i % 3 == 0
    s = sample(has_air=random.random() < .8, air=random.uniform(-10, 45), has_sun=random.random() < .7, sun=random.random(),
               sun_above=random.random() < .6, has_wind=random.random() < .5, wind=random.uniform(0, 15),
               has_hum=random.random() < .5, hum=random.random(), has_shelter=random.random() < .4,
               sh_sun=random.random(), sh_wind=random.random(),
               has_water=legacy, in_water=legacy and random.random() < .5, water_t=random.uniform(0, 30),
               has_profile=False, prof_t=random.choice([0.0, 14.0, NAN]))     # profile flag off: value must be ignored
    T = random.uniform(30, 41); dt = random.choice([.25, 5, 60, 300]); act = random.choice(["rest", "walk", "sprint", "swim"])
    if integrate_old(T, dt, s, act) != integrate_new(T, dt, s, act): diff += 1
check("1 air / legacy path: old and new results identical (60000 random samples, exact ==)", diff == 0, f"differences={diff}")
# 24 h air-path trajectory before vs after (resting from 08:00, air 20..30 curve)
def air_curve(h):
    cold, warm = 5.0, 15.0; rise = warm - cold; fall = 24 - rise; sc = (h % 24 - cold) % 24
    return -math.cos(math.pi * sc / rise) if sc <= rise else math.cos(math.pi * (sc - rise) / fall)
To = Tn = 37.0; h = 8.0; maxd = 0.0
for _ in range(24 * 60):
    h += 1 / 60; s = sample(has_air=True, air=25 + 5 * air_curve(h), has_sun=True, sun=max(0, math.sin((h % 24 - 6) / 12 * math.pi)), sun_above=6 < h % 24 < 18)
    To = integrate_old(To, 60, s, "rest"); Tn = integrate_new(Tn, 60, s, "rest"); maxd = max(maxd, abs(To - Tn))
check("1 air 24 h trajectory before vs after", maxd == 0.0, f"max |diff|={maxd}; end {To:.4f} vs {Tn:.4f}")

# 2. water 26 C: water temperature is used, not the air
W26 = sample(has_air=True, air=35.0, has_profile=True, prof_t=26.0, prof_depth=1.0)
g = B["basal"] / (B["normal"] - B["neutral"]) * B["water_mult"]
eq = (B["basal"] + g * 26.0) / g
T = advance(37.0, 400 * 3600, W26, "rest", integrate_new)
check("2 water 26 C: settles at water + basal/g (water used, air 35 ignored)", abs(T - max(B["tmin"], min(B["tmax"], eq))) < 1e-6, f"T={T:.4f} eq={eq:.4f} (clamped to min {B['tmin']})")
check("2 equilibrium would be far below the air one (air 35 -> 47)", eq < 35)
# 3. 14 C cools faster than air
W14 = sample(has_air=True, air=25.0, has_profile=True, prof_t=14.0)
Ta = advance(37.0, 300, AIR, "rest", integrate_new); Tw = advance(37.0, 300, W14, "rest", integrate_new); Tw26 = advance(37.0, 300, sample(has_air=True, air=25.0, has_profile=True, prof_t=26.0), "rest", integrate_new)
check("3 water 14 C cools faster than air 25 C (5 min, below the 25 C floor)", (37 - Tw) > (37 - Ta) and Tw < Tw26 < 37.0 and Tw > B["tmin"], f"air {Ta:.3f} / water26 {Tw26:.3f} / water14 {Tw:.3f}")
# 4. warm water heats the body
WH = sample(has_air=True, air=25.0, has_profile=True, prof_t=40.0)
T0 = 35.0; Th = advance(T0, 3600, WH, "rest", integrate_new)
check("4 water warmer than the body (40 C) warms it", Th > T0 + 0.5, f"{T0} -> {Th:.3f}")
check("4 same body in air (25 C) does not warm like that", advance(35.0, 3600, AIR, "rest", integrate_new) < T0 + 0.5)
# 5. profile unavailable: no water cooling, no 0 C default
for name, s in {
  "flag false, value default 0": sample(has_air=True, air=25.0, has_profile=False, prof_t=0.0),
  "flag false, value 5 (stale)": sample(has_air=True, air=25.0, has_profile=False, prof_t=5.0),
  "flag true but NaN": sample(has_air=True, air=25.0, has_profile=True, prof_t=NAN),
  "flag true but inf": sample(has_air=True, air=25.0, has_profile=True, prof_t=INF)}.items():
    r = advance(37.0, 7200, s, "rest", integrate_new); ra = advance(37.0, 7200, AIR, "rest", integrate_new)
    check(f"5 {name}: identical to plain air path, finite", r == ra and fin(r), f"{r:.4f}")
check("5 profile NaN with valid legacy water -> legacy used (compat)", water_env(sample(has_profile=True, prof_t=NAN, has_water=True, in_water=True, water_t=20.0)) == 20.0)
# 6. no provider at all (empty sample) -> neutral air, no error, no fake data
E = sample(); r = advance(37.0, 3600, E, "rest", integrate_new)
check("6 empty sample (no provider): neutral stand-in, same as old, finite", r == advance(37.0, 3600, E, "rest", integrate_old) and fin(r), f"{r:.4f}")
check("6 water_env(empty) = NAN (not 0 C)", math.isnan(water_env(E)))
# 7. coefficient 25 exactly once
T1, nm, sw, pr = integrate_new(37.0, 60, W26, "rest", detail=True)
check("7 water path applies water_conductance_multiplier exactly once", nm == 1)
g1 = B["basal"] / (B["normal"] - B["neutral"]); tau_w = B["C"] / (g1 * 25)
import math as m
exp_T = ((B["basal"] + g1 * 25 * 26) / (g1 * 25)); pred = exp_T + (37 - exp_T) * m.exp(-60 / tau_w)
check("7 one step equals exp solution with g = base x 25 (not 625)", abs(T1 - pred) < 1e-12 and B["water_mult"] == 25.0)
# 8. no solar, no sweat in water
SUN = sample(has_air=True, air=35.0, has_sun=True, sun=1.0, sun_above=True, has_hum=True, hum=0.0, has_profile=True, prof_t=26.0)
NOSUN = dict(SUN, has_sun=False)
a = integrate_new(38.5, 60, SUN, "rest", detail=True); b = integrate_new(38.5, 60, NOSUN, "rest", detail=True)
check("8 hot body (38.5) in water, full sun: no solar heat, no sweat", a[0] == b[0] and a[2] == 0.0 and a[3] == B["basal"], f"sweat={a[2]} production={a[3]}")
oa = integrate_new(38.5, 60, dict(SUN, has_profile=False), "rest", detail=True)
check("8 same body in AIR still gets sun and sweat (regression guard)", oa[2] > 0 and oa[3] > B["basal"])
check("8 activity heat kept in water (swim +350 W)", integrate_new(37.0, 60, W26, "swim", detail=True)[3] == B["basal"] + B["swim"])
check("8 wind ignored in water", integrate_new(37, 60, dict(W26, has_wind=True, wind=12.0), "rest") == integrate_new(37, 60, W26, "rest"))
# 9. time base: substeps and acceleration give the same result (exact exponential)
res = {}
for label, parts in (("1x3600s", [3600.0]), ("12x300s", [300.0] * 12), ("720x5s", [5.0] * 720), ("36x100s (accelerated chunks)", [100.0] * 36)):
    Tq = 37.0
    for st in parts: Tq = advance(Tq, st, W26, "rest", integrate_new)
    res[label] = Tq
base3600 = res["1x3600s"]
check("9 substeps: 1x3600 == 12x300 == 720x5 == 36x100 (water 26 C, not at equilibrium or floor)", all(abs(v - base3600) < 1e-9 for v in res.values()) and 26.7 < base3600 < 36.0, str({k: round(v, 6) for k, v in res.items()}))
Tbig = advance(37.0, 3600.0 * 3, W26, "rest", integrate_new); Tstep = 37.0
for _ in range(3): Tstep = advance(Tstep, 3600.0, W26, "rest", integrate_new)
check("9 one 3 h call (36 substeps) == three 1 h calls", abs(Tbig - Tstep) < 1e-9, f"{Tbig:.6f}")
# finite always
ok = True
for _ in range(20000):
    s = sample(has_air=random.random() < .5, air=random.uniform(-60, 60), has_profile=random.random() < .7, prof_t=random.choice([random.uniform(-2, 40), NAN, INF, -INF, 0.0]),
               has_water=random.random() < .3, in_water=random.random() < .5, water_t=random.choice([random.uniform(0, 30), NAN, INF]))
    ok &= fin(advance(random.uniform(30, 41), random.choice([1, 300, 5000, 90000]), s, random.choice(["rest", "walk", "swim"]), integrate_new))
check("NaN/inf never reach the body temperature (20000 random samples)", ok)
# legacy compat explicit
LEG = sample(has_air=True, air=25.0, has_water=True, in_water=True, water_t=18.0)
check("legacy has_water/is_in_water/water_temperature still works", integrate_old(37, 60, LEG, "rest") == integrate_new(37, 60, LEG, "rest") and integrate_new(37, 60, LEG, "rest") < integrate_new(37, 60, AIR, "rest"))
check("profile wins over legacy when both are present", water_env(dict(LEG, has_profile=True, prof_t=26.0)) == 26.0)
print("\nRESULT:", "ALL PASS" if not fails else f"{len(fails)} FAIL: {fails}")
raise SystemExit(1 if fails else 0)

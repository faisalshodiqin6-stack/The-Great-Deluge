#!/usr/bin/env python3
"""Offline replica of BodyTemperature._integrate (TP-05A-04F calibration).
Mirrors scripts/systems/body_temperature.gd + world_environment_data.gd + the sun curve
of day_night_cycle.gd / sun_exposure_provider.gd. Not used by the game. Pure stdlib.
Usage: python3 tools/body_temperature_sim.py"""
import math

TAU = 2 * math.pi
BASE = dict(normal=37.0, C=250000.0, basal=80.0, walk=150.0, sprint=450.0, sweat=300.0,
            neutral=25.0, sun_w=300.0, tmin=25.0, tmax=44.0,
            mean=25.0, swing=5.0, cold_h=5.0, warm_h=15.0, sun_max_elev=65.0)

def air_curve(h, p):
    cold, warm = p["cold_h"] % 24, p["warm_h"] % 24
    rise = (warm - cold) % 24
    fall = 24 - rise
    s = (h % 24 - cold) % 24
    return -math.cos(math.pi * s / rise) if s <= rise else math.cos(math.pi * (s - rise) / fall)

def air_at(h, p):          # WorldEnvironmentData, default region, sea level
    return p["mean"] + p["swing"] * air_curve(h, p)

def sun_at(h, p):          # DayNightCycle elevation + SunExposureProvider intensity
    t = (h % 24) / 24.0
    elev = math.sin((t - 0.25) * TAU) * p["sun_max_elev"]
    if elev <= 0: return 0.0
    return min(1.0, math.sin(math.radians(elev)) / math.sin(math.radians(p["sun_max_elev"])))

def step(T, dt, h_end, act, p, air=None, sun_on=True):
    air = air_at(h_end, p) if air is None else air
    sun = sun_at(h_end, p) if sun_on else 0.0
    g = p["basal"] / max(p["normal"] - p["neutral"], 0.1)
    prod = p["basal"] + {"rest": 0, "walk": p["walk"], "sprint": p["sprint"]}[act] + p["sun_w"] * sun
    sw = p["sweat"] if T > p["normal"] else 0.0
    tot = g + sw
    eq = (prod + g * air + sw * p["normal"]) / tot
    tau = p["C"] / tot
    return min(max(eq + (T - eq) * math.exp(-dt / tau), p["tmin"]), p["tmax"])

def run(p, hours, dt, schedule, air=None, sun_on=True, start_h=8.0, T0=37.0):
    """schedule(hour_of_day)->'rest'|'walk'. Returns list of (hour_abs, T) sampled each step."""
    T, h, out = T0, start_h, []
    n = int(round(hours * 3600 / dt))
    for _ in range(n):
        h += dt / 3600.0                      # game samples the environment after the clock moved
        T = step(T, dt, h, schedule(h % 24), p, air, sun_on)
        out.append((h, T))
    return out

def stats(series, h_from, h_to):
    seg = [(h, T) for h, T in series if h_from < h <= h_to]
    lo = min(seg, key=lambda x: x[1]); hi = max(seg, key=lambda x: x[1])
    return lo[1], lo[0] % 24, hi[1], hi[0] % 24

REST = lambda h: "rest"
DAYWALK = lambda h: "walk" if 6 <= h < 18 else "rest"

ALTS = {
    "A baseline  N25 C250k":          dict(),
    "B N22":                          dict(neutral=22.0),
    "C N20":                          dict(neutral=20.0),
    "D N25 C500k":                    dict(C=500000.0),
    "E N22 C350k":                    dict(neutral=22.0, C=350000.0),
    "F N25 air 27+-4":                dict(mean=27.0, swing=4.0),
    "G N21":                          dict(neutral=21.0),
}
def P(**kw):
    d = dict(BASE); d.update(kw); return d

if __name__ == "__main__":
    DT = 5.0
    print("== 1. Root cause (baseline): resting equilibrium = air + basal/g")
    g = BASE["basal"] / (BASE["normal"] - BASE["neutral"])
    print("g = %.3f W/C, tau = %.1f h, T_eq(air)=air+%.1f" % (g, BASE["C"] / g / 3600, BASE["basal"] / g))
    print("== 2. Rest 24 h from 08:00 (variable air 20..30), per alternative; no sun / sun 300 W")
    print("%-24s | no-sun min@h  max@h      | sun300 min@h  max@h" % "alt")
    for name, kw in ALTS.items():
        a = run(P(**kw), 24, DT, REST, sun_on=False); b = run(P(**kw), 24, DT, REST)
        l1, hl1, h1, hh1 = stats(a, 8, 32); l2, hl2, h2, hh2 = stats(b, 8, 32)
        print("%-24s | %.2f@%04.1f %.2f@%04.1f | %.2f@%04.1f %.2f@%04.1f" % (name, l1, hl1, h1, hh1, l2, hl2, h2, hh2))

    def hours_below(p, air, limit, sched=REST, maxh=96):
        T, h = 37.0, 8.0
        while h < 8 + maxh:
            h += 60 / 3600.0
            T = step(T, 60.0, h, sched(h % 24), p, air=air, sun_on=False)
            if T < limit: return h - 8
        return None

    print("\n== 3. Steady daily cycle (day 3 of 3), variable air 20..30: min/max core temperature")
    print("%-24s | rest sun0     | rest sun300   | day-walk sun0 | day-walk sun300" % "alt")
    for name, kw in ALTS.items():
        row = []
        for sched in (REST, DAYWALK):
            for sun_on in (False, True):
                s = run(P(**kw), 72, DT, sched, sun_on=sun_on)
                lo, hl, hi, hh = stats(s, 8 + 48, 8 + 72)
                row.append("%.2f/%.2f" % (lo, hi))
        print("%-24s | %-13s | %-13s | %-13s | %s" % (name, row[0], row[1], row[2], row[3]))

    print("\n== 4. Constant air, resting, 24 h from 37.0 (sun0 end T / sun300 [day curve] max T); sun0 is the cold test")
    print("%-24s |  20C sun0  20C sun300 |  25C sun0  25C sun300 |  30C sun0  30C sun300" % "alt")
    for name, kw in ALTS.items():
        cells = []
        for air in (20.0, 25.0, 30.0):
            a = run(P(**kw), 24, DT, REST, air=air, sun_on=False)
            b = run(P(**kw), 24, DT, REST, air=air, sun_on=True)
            cells.append("min %.2f / end %.2f" % (min(T for _, T in a), a[-1][1]))
            cells.append("max %.2f" % max(T for _, T in b))
        print("%-24s | %s %s | %s %s | %s %s" % ((name,) + tuple(cells)))

    print("\n== 5. Cold must still cause hypothermia: hours of constant air (resting, no sun) until core < 35 C ('-' = never within 96 h)")
    print("%-24s | 15C   10C    5C    0C   | asymptote at 15/10/5/0 C" % "alt")
    for name, kw in ALTS.items():
        p = P(**kw); g = p["basal"] / (p["normal"] - p["neutral"])
        hs = []
        for air in (15.0, 10.0, 5.0, 0.0):
            v = hours_below(p, air, 35.0)
            hs.append("%5.1f" % v if v is not None else "    -")
        print("%-24s | %s | %s" % (name, " ".join(hs), " / ".join("%.1f" % (a + p["basal"] / g) for a in (15, 10, 5, 0))))

    print("\n== 6. Hot air still raises core temperature (constant air, 24 h, no sun): max core temp resting / walking")
    for name, kw in ALTS.items():
        cells = []
        for air in (35.0, 40.0):
            for sched in (REST, lambda h: "walk"):
                s = run(P(**kw), 24, DT, sched, air=air, sun_on=False)
                cells.append("%.2f" % max(T for _, T in s))
        print("%-24s | 35C rest %s walk %s | 40C rest %s walk %s" % ((name,) + tuple(cells)))

    print("\n== 7. Step-size check (rest 24 h, variable air, sun300): min / max core temp; frame step 0.25 s uses the baseline only")
    for name in ("A baseline  N25 C250k", "B N22", "G N21"):
        kw = ALTS[name]; cells = []
        for dt in (5.0, 60.0, 300.0, 900.0):
            s = run(P(**kw), 24, dt, REST); lo, hl, hi, hh = stats(s, 8, 32)
            cells.append("dt %4.0fs: %.3f/%.3f" % (dt, lo, hi))
        print("%-24s | %s" % (name, " | ".join(cells)))
    s = run(P(), 24, 0.25, REST); lo, hl, hi, hh = stats(s, 8, 32)
    print("baseline frame step 0.25 s: %.3f/%.3f" % (lo, hi))

    print("\n== 8. Cause of the night drop (baseline, rest from 08:00, no sun): equilibrium, body temperature and net power by hour")
    p = P(); g0 = p["basal"] / (p["normal"] - p["neutral"])
    s = run(p, 24, DT, REST, sun_on=False)
    for h in (20, 22, 0, 2, 4, 5, 8):
        hh = h + 24 if h <= 8 else h
        T = min(s, key=lambda x: abs(x[0] - hh))[1]
        air = air_at(h, p); eq = air + p["basal"] / g0; net = g0 * (eq - T)
        print("  %02d:00 air %.1f C | equilibrium %.1f C | body %.2f C | net %+.0f W = %+.2f C/h (loss %.0f W vs 80 W produced)" % (h, air, eq, T, net, net * 3600 / p["C"], g0 * (T - air)))

    print("\n== 9. Solar gain comparison (NOT changed): rest / day-walk, steady day 3, min/max core temp")
    print("%-24s | sun W: %s" % ("alt", "   0          100         150         200         300"))
    for name in ("A baseline  N25 C250k", "B N22"):
        for label, sched in (("rest", REST), ("day-walk", DAYWALK)):
            cells = []
            for w in (0, 100, 150, 200, 300):
                sr = run(P(sun_w=float(w), **ALTS[name]), 72, DT, sched)
                lo, hl, hi, hh = stats(sr, 56, 80); cells.append("%.2f/%.2f" % (lo, hi))
            print("%-24s | %-8s %s" % (name, label, "  ".join(cells)))

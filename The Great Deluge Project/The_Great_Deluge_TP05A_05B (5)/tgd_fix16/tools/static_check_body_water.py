#!/usr/bin/env python3
"""Static checks for TP-05A-05B (text analysis only; NOT a Godot parse or runtime test).
Usage: python3 -I tools/static_check_body_water.py <project_root> <baseline_root>"""
import re, sys, os, difflib, glob
root, base = sys.argv[1], sys.argv[2]
fails = []
def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail else ""))
    if not ok: fails.append(name)
rd = lambda r, p: open(os.path.join(r, p), encoding="utf-8").read()
strip = lambda t: "\n".join(l.rstrip() for l in re.sub(r"#.*", "", t).splitlines())
BT = "scripts/systems/body_temperature.gd"
new, old = rd(root, BT), rd(base, BT)
nc, oc = strip(new), strip(old)

# Which files changed vs baseline
def files(r): return {os.path.relpath(f, r) for f in glob.glob(os.path.join(r, "**/*"), recursive=True) if os.path.isfile(f) and "/tools/" not in f and "/.godot/" not in f}
changed = sorted(f for f in files(root) | files(base) if (f not in files(root) or f not in files(base) or rd(root, f) != rd(base, f)))
check("game files changed vs baseline: only body_temperature.gd (+ docs)", [f for f in changed if not f.startswith("docs/")] == [BT], str(changed))
for f in ("scripts/systems/world_time.gd", "scripts/systems/day_night_cycle.gd", "scripts/systems/player_survival.gd", "scripts/systems/environment_sample.gd",
          "scripts/systems/water_temperature_data.gd", "scripts/systems/water_temperature_provider.gd", "scripts/systems/temperature_status_view.gd",
          "scripts/systems/world_air_temperature_provider.gd", "scripts/systems/sun_exposure_provider.gd", "scenes/world/world.tscn"):
    check(f"unchanged: {f}", rd(root, f) == rd(base, f))

# Removed / added code lines in body_temperature.gd (comments excluded)
d = [l for l in difflib.unified_diff(oc.splitlines(), nc.splitlines(), lineterm="", n=0) if l[:1] in "+-" and not l.startswith(("+++", "---"))]
removed = [l[1:].strip() for l in d if l[0] == "-" and l[1:].strip()]
check("only 2 code lines removed (the old in_water / env_temp lines)", removed == ["var in_water := s.has_water and s.is_in_water", "var env_temp := s.water_temperature if in_water else air"], str(removed))

# Heat-loss structure untouched
for frag in ("conductance *= water_conductance_multiplier", "production += solar_gain_full_sun * sun * (1.0 - sun_block)", "if _temperature > normal_temperature and not in_water:",
             "conductance *= 1.0 + wind_conductance_per_ms * wind * (1.0 - wind_block)", "exp(-dt / tau)", "var equilibrium := (production + conductance * env_temp + sweat * normal_temperature) / total_conductance"):
    check(f"kept: {frag[:60]}", frag in nc)
check("water_conductance_multiplier default still 25.0", "@export var water_conductance_multiplier: float = 25.0" in nc)
uses = [l for l in nc.splitlines() if "water_conductance_multiplier" in l and "@export" not in l]
check("multiplier applied exactly once in code", len(uses) == 1, str(uses))
check("substep loop in advance() unchanged", re.search(r"func advance.*?_update_effects\(\)", nc, re.S).group(0) == re.search(r"func advance.*?_update_effects\(\)", oc, re.S).group(0))
check("max_substep_seconds default unchanged", "max_substep_seconds: float = 300.0" in nc)

# Water source rules
fn = re.search(r"static func _water_environment_temperature.*?\n\n", nc, re.S).group(0)
check("profile requires has_water_profile AND finite value", "s.has_water_profile and not (is_nan(s.water_profile_temperature) or is_inf(s.water_profile_temperature))" in fn)
check("legacy requires has_water AND is_in_water AND finite value", "s.has_water and s.is_in_water and not (is_nan(s.water_temperature) or is_inf(s.water_temperature))" in fn)
check("returns NAN (not 0) when no water data", fn.rstrip().endswith("return NAN"))
check("depth / region fields not used in the heat formula", not re.search(r"water_profile_(depth|region)", re.search(r"func _integrate.*?\n\n", nc, re.S).group(0)))
check("_integrate does not read provider nodes or water_profile flag directly", "WaterTemperatureProvider" not in re.search(r"func _integrate.*?\n\n", nc, re.S).group(0))
check("env_temp uses water only when in_water", "var env_temp := water_temp if in_water else air" in nc and "var in_water := not is_nan(water_temp)" in nc)

# Status
gs = re.search(r"func get_data_status.*?\n\t}\n", nc, re.S).group(0)
for k in ('"water"', '"water_provider"', '"water_profile"', '"in_water"', '"water_source"', '"provider"'):
    check(f"get_data_status has {k}", k in gs)
check('status "in_water" is not derived from provider presence', "_water_environment_temperature(_sample)" in gs and "_has_water_profile_provider() and" not in gs)
check('legacy status key "water" still = _sample.has_water', '"water": _sample.has_water' in gs)
check("status view keys it iterates still exist", all(k in gs for k in ('"air_temperature"', '"sun"', '"wind"', '"humidity"', '"water"', '"shelter"', '"provider"')))

# Time base: no new listeners / double stepping
allgd = {f: strip(open(f, encoding="utf-8").read()) for f in glob.glob(os.path.join(root, "scripts/**/*.gd"), recursive=True)}
conn = sorted(os.path.relpath(f, root) for f, t in allgd.items() if "time_advanced" in t)
check("time_advanced used only by world_time (emit) and player_survival (single connect)", conn == ["scripts/systems/player_survival.gd", "scripts/systems/world_time.gd"], str(conn))
check("BodyTemperature has no time listener / _process / _physics_process", not re.search(r"time_advanced|func _process|func _physics_process|\.connect\(", nc))
adv = sorted(os.path.relpath(f, root) for f, t in allgd.items() if re.search(r"\.advance\(", t) and "body" in t.lower() and "player_survival" in f)
check("body.advance() is called only from player_survival (once per chunk)", len(re.findall(r"body\.advance\(", allgd[os.path.join(root, "scripts/systems/player_survival.gd")])) == 1 and
      not any(re.search(r"(body|_body|BodyTemperature)\w*\.advance\(", t) for f, t in allgd.items() if not f.endswith("player_survival.gd")))
check("water provider / data have no signal connections or _process", not re.search(r"\.connect\(|func _process|func _physics_process|time_advanced", allgd[os.path.join(root, "scripts/systems/water_temperature_provider.gd")] + allgd[os.path.join(root, "scripts/systems/water_temperature_data.gd")]))

# GDScript 4.3 hygiene on the changed file
check("tab indentation only", not re.search(r"^ +\S", new, re.M))
check("declared helpers exist: _water_environment_temperature, _water_source, _has_water_profile_provider", all(re.search(rf"func {n}\(", nc) for n in ("_water_environment_temperature", "_water_source", "_has_water_profile_provider")))
check("every call of those helpers matches a declaration", all(n in set(re.findall(r"func (\w+)\(", nc)) for n in set(re.findall(r"\b(_water_\w+|_has_water_profile_provider)\(", nc))))
check("static helpers do not touch instance state (no self fields)", not re.search(r"(?<![\w.])(_sample|_provider|_providers|_temperature)\b", fn))
check("WaterTemperatureProvider / EnvironmentSample class names exist", all(re.search(rf"^class_name {c}\b", rd(root, f"scripts/systems/{n}.gd"), re.M) for c, n in (("WaterTemperatureProvider", "water_temperature_provider"), ("EnvironmentSample", "environment_sample"))))
check("no 4.4+ syntax", not re.search(r"@abstract|uid://", new))
check("EnvironmentSample water_profile fields used by BodyTemperature all exist", all(re.search(rf"^var {f}\b", rd(root, "scripts/systems/environment_sample.gd"), re.M) for f in set(re.findall(r"s\.(has_water_profile|water_profile_\w+)", nc)) | {"has_water_profile"}))
miss = [m for f in glob.glob(os.path.join(root, "**/*.gd"), recursive=True) + glob.glob(os.path.join(root, "**/*.tscn"), recursive=True)
        for m in re.findall(r'res://[^"\')\s]+', open(f, encoding="utf-8").read()) if not os.path.exists(os.path.join(root, m[6:]))]
check("res:// references all exist", not miss, str(miss))
print("\nRESULT:", "ALL PASS" if not fails else f"{len(fails)} FAIL: {fails}")
raise SystemExit(1 if fails else 0)

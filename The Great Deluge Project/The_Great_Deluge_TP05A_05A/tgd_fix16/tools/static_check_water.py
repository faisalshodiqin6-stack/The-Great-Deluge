#!/usr/bin/env python3
"""Static checks for TP-05A-05A (no Godot needed; NOT a runtime test).
Usage: python3 -I tools/static_check_water.py <project_root>"""
import re, sys, os, glob

root = sys.argv[1] if len(sys.argv) > 1 else "."
fails = []
def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail else ""))
    if not ok: fails.append(name)
rd = lambda p: open(os.path.join(root, p), encoding="utf-8").read()

new = ["water_surface_provider", "flat_water_surface_provider", "water_temperature_reading", "water_temperature_data", "water_temperature_provider"]
files = [f"scripts/systems/{n}.gd" for n in new]
# 1. res:// references exist
missing = []
for f in glob.glob(os.path.join(root, "**/*.gd"), recursive=True) + glob.glob(os.path.join(root, "**/*.tscn"), recursive=True):
    for m in re.findall(r'res://[^"\')\s]+', open(f, encoding="utf-8").read()):
        if not os.path.exists(os.path.join(root, m[6:])): missing.append((os.path.relpath(f, root), m))
check("res:// references all exist (whole project)", not missing, str(missing))
# 2. world.tscn ids unique, node refs valid, parents exist
t = rd("scenes/world/world.tscn")
ids = re.findall(r'\[(?:ext|sub)_resource[^\]]*id="([^"]+)"', t)
check("world.tscn resource ids unique", len(ids) == len(set(ids)))
used = set(re.findall(r'(?:ExtResource|SubResource)\("([^"]+)"\)', t))
check("world.tscn: every used id is declared", used <= set(ids), str(used - set(ids)))
check("world.tscn: new nodes present", 'name="WaterTemperatureData"' in t and 'name="WaterTemperatureProvider"' in t)
names = re.findall(r'\[node name="([^"]+)"', t)
check("world.tscn node names unique", len(names) == len(set(names)))
# default NodePaths of the provider resolve in the scene (siblings under World)
check("provider default paths resolve (../WaterTemperatureData, ../Player; data ../Island)", all(n in names for n in ("WaterTemperatureData", "Player", "Island")))
# 3. class_name unique, extends known, declared methods
cls = {}
for f in glob.glob(os.path.join(root, "scripts/**/*.gd"), recursive=True):
    m = re.search(r"^class_name (\w+)", open(f, encoding="utf-8").read(), re.M)
    if m: cls.setdefault(m.group(1), []).append(f)
check("class_name unique project-wide", all(len(v) == 1 for v in cls.values()), str({k: v for k, v in cls.items() if len(v) > 1}))
for n in new:
    s = rd(f"scripts/systems/{n}.gd")
    ext = re.search(r"^extends (\w+)", s, re.M).group(1)
    check(f"{n}: extends {ext} is a known class/builtin", ext in cls or ext in ("Node", "Resource", "RefCounted"))
    check(f"{n}: tab indentation only", not re.search(r"^ +\S", s, re.M))
# methods called across the new scripts are declared
decl = lambda n: set(re.findall(r"^func (\w+)\(", rd(f"scripts/systems/{n}.gd"), re.M))
D = {n: decl(n) for n in new + ["environment_provider", "region_locator", "planar_region_locator"]}
need = [("water_temperature_data", "surface_provider.", {"get_water_depth", "get_description"}, "water_surface_provider"),
        ("water_temperature_provider", "_data.", {"query_at"}, "water_temperature_data"),
        ("water_temperature_data", "region_locator.", {"find_region", "has_regions", "get_description"}, "region_locator")]
for src, pref, ms, tgt in need:
    check(f"{src} -> {tgt}: {sorted(ms)} declared", ms <= D[tgt])
    s = rd(f"scripts/systems/{src}.gd")
    check(f"{src}: only calls known methods on {pref}", all(m in D[tgt] for m in re.findall(re.escape(pref) + r"(\w+)\(", s)))
check("provider overrides fill_sample(sample)", "fill_sample" in D["water_temperature_provider"] and "fill_sample" in D["environment_provider"])
check("flat provider overrides get_water_depth/get_description", {"get_water_depth", "get_description"} <= D["flat_water_surface_provider"])
# 4. Godot 4.3 compat: no 4.4+ features, no := on Variant, no reserved-name vars
strip = lambda t: re.sub(r"#.*", "", t)   # code without comments
alls = "".join(rd(f) for f in files)
code = "".join(strip(rd(f)) for f in files)
check("no 4.4+ syntax (@abstract, @export_custom unique ids, uid:// refs)", not re.search(r"@abstract|uid://", alls))
check("no 'var x := <untyped call>' on call()/get() results", not re.search(r":=\s*\w+\.(call|get|callv)\(", alls))
# 5. responsibility: provider writes only water_profile fields; no reset; no BodyTemperature/WorldTime changes
p = strip(rd("scripts/systems/water_temperature_provider.gd"))
writes = set(re.findall(r"^\s*sample\.(\w+)\s*=", p, re.M))
check("provider writes only has_water_profile / water_profile_*", writes and all(w == "has_water_profile" or w.startswith("water_profile_") for w in writes), str(sorted(writes)))
check("provider never calls reset() or touches has_water/is_in_water/water_temperature", not re.search(r"\.reset\(\)|sample\.(has_water\b|is_in_water|water_temperature\b)", p))
check("BodyTemperature does not read water_profile fields (no integration yet)", "water_profile" not in rd("scripts/systems/body_temperature.gd"))
es = rd("scripts/systems/environment_sample.gd")
fields = re.findall(r"^var (has_water_profile|water_profile_\w+)", es, re.M)
reset_body = es.split("func reset()")[1]
check("EnvironmentSample: every water_profile field declared AND reset()", fields and all(re.search(rf"^\t{f} =", reset_body, re.M) for f in fields), str(fields))
check("SunExposure/WorldAir providers untouched (no water_profile refs)", all("water_profile" not in rd(f"scripts/systems/{x}.gd") for x in ("sun_exposure_provider", "world_air_temperature_provider", "world_environment_data")))
bt = rd("scripts/systems/body_temperature.gd")
check("BodyTemperature: water_conductance_multiplier still 25.0", "water_conductance_multiplier: float = 25.0" in bt)
check("new scripts (code) do not reference WorldTime / DayNightCycle / BodyTemperature", not re.search(r"WorldTime|DayNightCycle|BodyTemperature|world_time|day_night", code))
print("\nRESULT:", "ALL PASS" if not fails else f"{len(fails)} FAIL: {fails}")
raise SystemExit(1 if fails else 0)

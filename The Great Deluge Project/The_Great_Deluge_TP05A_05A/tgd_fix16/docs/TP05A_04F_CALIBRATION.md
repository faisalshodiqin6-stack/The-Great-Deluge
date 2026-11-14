# TP-05A-04F — Air / body temperature calibration

Tool: `tools/body_temperature_sim.py` (stdlib Python replica of `BodyTemperature._integrate`, the `WorldEnvironmentData` air curve and the `DayNightCycle` sun curve). Full output: `tools/body_temperature_sim_output.txt`. Replica check: baseline with 0 W / 300 W sun gives 34.67 / 37.10 and 35.01 / 38.05 for the first 24 h, the same numbers as TP-05A-04E.

## Cause (quantified)
- Heat loss is linear: `loss = g * (T - air)`, `g = basal_heat / (normal - neutral_air_temperature) = 80 / 12 = 6.67 W/°C`.
- A resting body (no sun, no sweat) therefore settles at `air + 80/g = air + 12 °C`: **1 °C of air = 1 °C of body temperature**. Air 20 °C -> equilibrium 32 °C. The model has no thermoregulation, so nothing resists this.
- The neutral value (25) equals the air MEAN, so for half of every day (22:00 - ~10:00) the air is below it. Equilibrium is 37 at 22:00, 34.8 at 00:00, 33.1 at 02:00, 32.0 at 05:00. The body follows with time constant `C/g = 250000 / 6.67 = 10.4 h`.
- Resting from 08:00, no sun: body 37.01 (22:00) -> 36.29 (02:00) -> 35.30 (05:00) -> 34.67 (08:00; air is still below 25 until ~10:00). Net power is -13 .. -23 W (-0.2 .. -0.34 °C/h) all night.
- Not a bug in the integrator: 0.25 s, 5 s, 60 s, 300 s and 900 s steps agree within 0.01 °C (min 34.986 / 34.985 / 34.978 °C for 5 / 300 / 900 s, sun 300 W).

## Alternatives tested (all else unchanged; sun = 300 W unless stated)
| id | change | why |
|---|---|---|
| A | baseline: neutral 25, C 250 kJ/°C | reference |
| B | neutral 22 | lowers g to 5.33: balance point below the night air |
| C | neutral 20 | night minimum of the air = balance point |
| G | neutral 21 | between B and C |
| D | C 500 kJ/°C | slower body; tests "just add thermal mass" |
| E | neutral 22 + C 350 kJ/°C | combination |
| F | air mean 27 ± 4 (neutral 25) | tests the environment default instead of the body |
Heat capacity 250 kJ/°C already matches ~70 kg x 3.5 kJ/kg/°C, so D/E are not physically motivated; they were run to show they only delay.

## Results
Steady day (day 3 of 3), default air 20..30 °C, min / max core temperature:

| alt | rest, no sun | rest, sun 300 | day-walk (06-18), no sun | day-walk, sun 300 |
|---|---|---|---|---|
| A | 34.65 / 37.11 | 34.99 / 38.05 | 35.01 / 37.60 | 35.01 / 38.54 |
| B | **36.44 / 37.14** | 36.51 / 38.09 | 36.52 / 37.63 | 36.52 / 38.58 |
| C | 37.00 / 37.15 | 37.00 / 38.11 | 37.00 / 37.65 | 37.00 / 38.60 |
| D | 35.57 / 37.09 | 35.85 / 38.05 | 35.87 / 37.60 | 35.87 / 38.54 |
| E | 36.57 / 37.14 | 36.64 / 38.09 | 36.64 / 37.63 | 36.64 / 38.58 |
| F | 36.27 / 37.13 | 36.37 / 38.08 | 36.37 / 37.62 | 36.37 / 38.57 |
| G | 36.80 / 37.15 | 36.82 / 38.10 | 36.82 / 37.64 | 36.82 / 38.59 |

Constant air, resting, 24 h from 37.0 °C, no sun (lowest temperature reached) and highest temperature with sun 300 W:

| alt | 20 °C | 25 °C | 30 °C | max with sun at 20 / 25 / 30 °C |
|---|---|---|---|---|
| A | 32.50 | 37.00 | 37.00 (end 37.11) | 37.87 / 37.98 / 38.09 |
| B | 35.32 | 37.00 | 37.00 (end 37.14) | 37.95 / 38.03 / 38.12 |
| C | 37.00 | 37.00 | 37.00 (end 37.15) | 37.98 / 38.06 / 38.14 |
| D | 33.58 | 37.00 | 37.00 (end 37.11) | 37.87 / 37.97 / 38.08 |
| G | 36.18 | 37.00 | 37.00 (end 37.14) | 37.97 / 38.05 / 38.13 |

Cold must still hurt: hours at constant air (resting, no sun) until core < 35 °C (Hipotermia):

| alt | 15 °C | 10 °C | 5 °C | 0 °C | asymptote at 15 / 10 / 5 / 0 °C |
|---|---|---|---|---|---|
| A | 2.3 | 1.5 | 1.1 | 0.9 | 27 / 22 / 17 / 12 |
| B | **4.4** | 2.4 | 1.6 | 1.3 | 30 / 25 / 20 / 15 |
| C | 7.6 | 3.3 | 2.1 | 1.6 | 32 / 27 / 22 / 17 |
| D | 4.7 | 3.0 | 2.2 | 1.8 | 27 / 22 / 17 / 12 |
| G | 5.6 | 2.8 | 1.9 | 1.4 | 31 / 26 / 21 / 16 |
(game hours; 1 real minute = 15 game minutes)

Hot air still raises temperature (constant air, no sun, 24 h, max core temp): 35 °C air rest 37.22 / walk 37.71, 40 °C air rest 37.31-37.33 / walk 37.80-37.82 for every alternative (the 300 W/°C sweat term dominates; the choice of neutral changes it by < 0.02 °C).

Solar gain comparison (NOT changed), steady day, min / max:

| sun W | 0 | 100 | 150 | 200 | 300 |
|---|---|---|---|---|---|
| A rest | 34.65 / 37.11 | 34.94 / 37.41 | 34.96 / 37.57 | 34.97 / 37.73 | 34.99 / 38.05 |
| B rest | 36.44 / 37.14 | 36.51 / 37.44 | 36.51 / 37.60 | 36.51 / 37.77 | 36.51 / 38.09 |
| A day-walk | 35.01 / 37.60 | 35.01 / 37.90 | 35.01 / 38.06 | 35.01 / 38.22 | 35.01 / 38.54 |
| B day-walk | 36.52 / 37.63 | 36.52 / 37.94 | 36.52 / 38.10 | 36.52 / 38.26 | 36.52 / 38.58 |
Neutral 22 only moves the night minimum; the daytime maximum is set by sun, activity and sweat, so the sun parameter stays a separate decision.

## Recommendation (temporary)
- **`neutral_air_temperature` = 22** (applied as the default in `body_temperature.gd`). Resting night minimum 36.44 °C (Normal, >= 36), constant 20 °C slowly reaches ~35.3 °C (Dingin, not hypothermia), constant 15 °C gives Hipotermia in 4.4 game hours (about 18 real minutes), 10 °C in 2.4 h. Hot behavior unchanged. Not immune: below ~20 °C the body still cools without limit toward `air + 15`.
- `neutral_air_temperature` 21 (G) is the next step if play-testing still finds nights too cold; 20 (C) makes the default 20..30 °C range completely harmless and cold effects start only below 20 °C.
- Keep heat capacity 250 kJ/°C, the air defaults (mean 25, swing 5), and `solar_gain_full_sun` 300 W until play-tested (table above: 100-150 W keeps a resting player Normal at noon; 300 W reaches Panas, and walking in sun reaches Stres panas).
- Side effects of lowering neutral: the stand-in air for missing data is 22 °C (resting balance stays 37 °C); water heat loss (25 x g) is 20 % lower, so the earlier "Hipotermia in ~2 game minutes at 10 °C water" estimate gets slightly slower. Re-tune when water exists.

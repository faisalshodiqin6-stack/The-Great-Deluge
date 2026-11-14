extends RefCounted
class_name TemperatureUI

## Shared, UI-only helpers for showing body temperature (HUD readout + Status tab).
## Holds no state and never changes any survival value.

## Chip background per BodyTemperature.Category (dark enough for white text).
const CHIP_COLORS := {
	BodyTemperature.Category.NORMAL: Color(0.18, 0.45, 0.25),
	BodyTemperature.Category.COLD: Color(0.20, 0.42, 0.62),
	BodyTemperature.Category.HYPOTHERMIA: Color(0.16, 0.30, 0.70),
	BodyTemperature.Category.SEVERE_HYPOTHERMIA: Color(0.38, 0.18, 0.62),
	BodyTemperature.Category.HOT: Color(0.70, 0.36, 0.08),
	BodyTemperature.Category.HEAT_STRESS: Color(0.78, 0.25, 0.12),
	BodyTemperature.Category.CRITICAL_HEAT: Color(0.70, 0.10, 0.12),
}
## Lighter variants for coloured text on the dark window background.
const TEXT_COLORS := {
	BodyTemperature.Category.NORMAL: Color(0.55, 0.85, 0.60),
	BodyTemperature.Category.COLD: Color(0.60, 0.80, 0.95),
	BodyTemperature.Category.HYPOTHERMIA: Color(0.55, 0.70, 1.00),
	BodyTemperature.Category.SEVERE_HYPOTHERMIA: Color(0.78, 0.62, 1.00),
	BodyTemperature.Category.HOT: Color(1.00, 0.72, 0.40),
	BodyTemperature.Category.HEAT_STRESS: Color(1.00, 0.55, 0.40),
	BodyTemperature.Category.CRITICAL_HEAT: Color(1.00, 0.42, 0.42),
}

static func find_body(tree: SceneTree) -> BodyTemperature:
	return tree.get_first_node_in_group("body_temperature") as BodyTemperature

static func chip_color(category: int) -> Color:
	return CHIP_COLORS.get(category, Color(0.3, 0.3, 0.3))

static func text_color(category: int) -> Color:
	return TEXT_COLORS.get(category, Color(1, 1, 1))

## One decimal, truncated (not rounded) so the number never contradicts the category:
## category thresholds are multiples of 0.1 °C, so 35.96 shows as 35.9 (Dingin), not 36.0.
static func format_temp(value: float) -> String:
	return "%.1f °C" % (floorf(value * 10.0 + 0.000001) / 10.0)

## "36.0" without the unit, for threshold ranges.
static func format_plain(value: float) -> String:
	return "%.1f" % value

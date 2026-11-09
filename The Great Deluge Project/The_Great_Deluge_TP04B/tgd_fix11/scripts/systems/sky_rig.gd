extends Node3D
class_name SkyRig

## Star dome + moon disc that follow the active camera (so they stay "at
## infinity"). Pure visuals: DayNightCycle tells it what to show.
const DOME_RADIUS := 900.0
const MOON_DISTANCE := 700.0
const MOON_QUAD_SIZE := 28.0
const STAR_AXIS := Vector3(0.3, 0.9, 0.3)

var _star_dome: MeshInstance3D
var _moon: MeshInstance3D
var _star_material: ShaderMaterial
var _moon_material: ShaderMaterial

func _ready() -> void:
	_star_material = ShaderMaterial.new()
	_star_material.shader = load("res://assets/materials/star_dome.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = DOME_RADIUS
	sphere.height = DOME_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_star_dome = MeshInstance3D.new()
	_star_dome.mesh = sphere
	_star_dome.material_override = _star_material
	_star_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star_dome.extra_cull_margin = 16384.0
	add_child(_star_dome)

	_moon_material = ShaderMaterial.new()
	_moon_material.shader = load("res://assets/materials/moon_disc.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(MOON_QUAD_SIZE, MOON_QUAD_SIZE)
	_moon = MeshInstance3D.new()
	_moon.mesh = quad
	_moon.material_override = _moon_material
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.extra_cull_margin = 16384.0
	add_child(_moon)
	_moon.visible = false
	_star_dome.visible = false

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position

## alpha 0..1. Hidden entirely at 0 (no draw cost by day).
func set_stars(alpha: float) -> void:
	_star_dome.visible = alpha > 0.005
	_star_material.set_shader_parameter("intensity", alpha)

## t = normalized day time; the sky turns once per day.
func set_sky_rotation(t: float) -> void:
	_star_dome.transform.basis = Basis(STAR_AXIS.normalized(), t * TAU)

## direction = unit vector from the viewer toward the moon.
func set_moon(direction: Vector3, alpha: float) -> void:
	_moon.visible = alpha > 0.005
	_moon.position = direction * MOON_DISTANCE
	_moon_material.set_shader_parameter("alpha", alpha)

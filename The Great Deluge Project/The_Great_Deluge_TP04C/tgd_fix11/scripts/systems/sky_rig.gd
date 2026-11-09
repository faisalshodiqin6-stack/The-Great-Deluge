extends Node3D
class_name SkyRig

## Star dome + sun disc + moon disc that follow the active camera (so they stay
## "at infinity"). Pure visuals: DayNightCycle tells it what to show.
## Disc sizes are real angular diameters converted to world size at a fixed
## distance, so the apparent size is perspective-correct and does not change
## when the camera moves or rotates.
const DOME_RADIUS := 900.0
const DISC_DISTANCE := 700.0
const DISC_RADIUS_UV := 0.2      # Disc radius inside its quad (quad space -1..1).
const STAR_AXIS := Vector3(0.3, 0.9, 0.3)

var _star_dome: MeshInstance3D
var _sun: MeshInstance3D
var _moon: MeshInstance3D
var _star_material: ShaderMaterial
var _sun_material: ShaderMaterial
var _moon_material: ShaderMaterial
var _sun_quad: QuadMesh
var _moon_quad: QuadMesh
var _last_sizes := Vector3(-1.0, -1.0, -1.0)

func _ready() -> void:
	_star_material = ShaderMaterial.new()
	_star_material.shader = load("res://assets/materials/star_dome.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = DOME_RADIUS
	sphere.height = DOME_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_star_dome = _make_instance(sphere, _star_material)
	_star_dome.visible = false

	_sun_material = ShaderMaterial.new()
	_sun_material.shader = load("res://assets/materials/sun_disc.gdshader")
	_sun_material.set_shader_parameter("disc_radius", DISC_RADIUS_UV)
	_sun_quad = QuadMesh.new()
	_sun = _make_instance(_sun_quad, _sun_material)
	_sun.visible = false

	_moon_material = ShaderMaterial.new()
	_moon_material.shader = load("res://assets/materials/moon_disc.gdshader")
	_moon_material.set_shader_parameter("disc_radius", DISC_RADIUS_UV)
	_moon_quad = QuadMesh.new()
	_moon = _make_instance(_moon_quad, _moon_material)
	_moon.visible = false

func _make_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 16384.0
	add_child(instance)
	return instance

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position

## Real angular diameters (degrees) -> quad world sizes. Only recomputed on change.
func set_angular_sizes(sun_deg: float, moon_deg: float, multiplier: float) -> void:
	var sizes := Vector3(sun_deg, moon_deg, multiplier)
	if sizes == _last_sizes or _sun_quad == null:
		return
	_last_sizes = sizes
	_sun_quad.size = Vector2.ONE * _quad_size_for(sun_deg * multiplier)
	_moon_quad.size = Vector2.ONE * _quad_size_for(moon_deg * multiplier)

## Disc diameter = 2 * d * tan(angle / 2); the quad is larger by 1 / disc radius.
func _quad_size_for(angular_diameter_deg: float) -> float:
	return 2.0 * DISC_DISTANCE * tan(deg_to_rad(angular_diameter_deg) / 2.0) / DISC_RADIUS_UV

## alpha 0..1. Hidden entirely at 0 (no draw cost by day).
func set_stars(alpha: float) -> void:
	_star_dome.visible = alpha > 0.005
	_star_material.set_shader_parameter("intensity", alpha)

## t = normalized day time; the sky turns once per day.
func set_sky_rotation(t: float) -> void:
	_star_dome.transform.basis = Basis(STAR_AXIS.normalized(), t * TAU)

## direction = unit vector from the viewer toward the sun.
func set_sun(direction: Vector3, color: Color, alpha: float, glow: float) -> void:
	_sun.visible = alpha > 0.005
	_sun.position = direction * DISC_DISTANCE
	_sun_material.set_shader_parameter("sun_color", color)
	_sun_material.set_shader_parameter("alpha", alpha)
	_sun_material.set_shader_parameter("glow_strength", glow)

## direction = unit vector from the viewer toward the moon.
func set_moon(direction: Vector3, alpha: float, glow: float) -> void:
	_moon.visible = alpha > 0.005
	_moon.position = direction * DISC_DISTANCE
	_moon_material.set_shader_parameter("alpha", alpha)
	_moon_material.set_shader_parameter("glow_strength", glow)

extends MeshInstance3D

## Builds a small, low-poly island with a smooth elliptical shoreline.
## Grass covers the raised center; sand forms a continuous outer beach.

const SEGMENTS: int = 64
const GRASS_RINGS: int = 18
const BEACH_RINGS: int = 6
const HALF_WIDTH: float = 34.0
const HALF_DEPTH: float = 25.0
const MAX_HEIGHT: float = 9.0
const GRASS_RADIUS: float = 0.82
const OUTER_RADIUS: float = 1.01


func _ready() -> void:
	_build_island_mesh()


func _build_island_mesh() -> void:
	var island_mesh := ArrayMesh.new()
	_add_radial_band(island_mesh, 0.0, GRASS_RADIUS, GRASS_RINGS, _make_material(Color(0.22, 0.39, 0.16, 1.0)))
	_add_radial_band(island_mesh, GRASS_RADIUS, OUTER_RADIUS, BEACH_RINGS, _make_material(Color(0.72, 0.62, 0.39, 1.0)))
	mesh = island_mesh


func _add_radial_band(
	island_mesh: ArrayMesh,
	inner_radius: float,
	outer_radius: float,
	ring_count: int,
	material: Material
) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)

	for ring_index in range(ring_count):
		var radius_a := lerpf(inner_radius, outer_radius, float(ring_index) / float(ring_count))
		var radius_b := lerpf(inner_radius, outer_radius, float(ring_index + 1) / float(ring_count))

		for segment in range(SEGMENTS):
			var angle_a := TAU * float(segment) / float(SEGMENTS)
			var angle_b := TAU * float(segment + 1) / float(SEGMENTS)
			var inner_a := _island_vertex(radius_a, angle_a)
			var inner_b := _island_vertex(radius_a, angle_b)
			var outer_a := _island_vertex(radius_b, angle_a)
			var outer_b := _island_vertex(radius_b, angle_b)

			# This winding order makes the triangles face upward.
			surface.add_vertex(inner_a)
			surface.add_vertex(inner_b)
			surface.add_vertex(outer_a)
			surface.add_vertex(inner_b)
			surface.add_vertex(outer_b)
			surface.add_vertex(outer_a)

	surface.generate_normals()
	surface.commit(island_mesh)


func _island_vertex(radius: float, angle: float) -> Vector3:
	var x_position := cos(angle) * HALF_WIDTH * radius
	var z_position := sin(angle) * HALF_DEPTH * radius
	var falloff := maxf(0.0, 1.0 - radius / OUTER_RADIUS)
	var main_height := pow(falloff, 1.55) * MAX_HEIGHT
	var gentle_variation := sin(x_position * 0.13) * cos(z_position * 0.17) * 0.45 * falloff
	return Vector3(x_position, maxf(0.0, main_height + gentle_variation), z_position)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

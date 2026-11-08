extends MeshInstance3D

## Builds the visible island and a separate height-map collider.
## The visual mesh keeps its radial detail, while physics uses a regular
## height grid to avoid tiny triangle seams under CharacterBody3D.
const SEGMENTS: int = 64
const GRASS_RINGS: int = 18
const BEACH_RINGS: int = 6
const HALF_WIDTH: float = 34.0
const HALF_DEPTH: float = 25.0
const MAX_HEIGHT: float = 9.0
const GRASS_RADIUS: float = 0.82
const OUTER_RADIUS: float = 1.01
const PLATEAU_RADIUS: float = 0.20
const COLLISION_SEABED_HEIGHT: float = -1.0

func _ready() -> void:
    _build_island_mesh()
    _create_collision()

func _build_island_mesh() -> void:
    var island_mesh := ArrayMesh.new()
    _add_radial_band(island_mesh, 0.0, GRASS_RADIUS, GRASS_RINGS, _make_material(Color(0.22, 0.39, 0.16, 1.0)))
    _add_radial_band(island_mesh, GRASS_RADIUS, OUTER_RADIUS, BEACH_RINGS, _make_material(Color(0.72, 0.62, 0.39, 1.0)))
    mesh = island_mesh

func _create_collision() -> void:
    var terrain_shape := HeightMapShape3D.new()
    var map_width := int(HALF_WIDTH * 2.0) + 1
    var map_depth := int(HALF_DEPTH * 2.0) + 1
    terrain_shape.map_width = map_width
    terrain_shape.map_depth = map_depth

    var height_data := PackedFloat32Array()
    height_data.resize(map_width * map_depth)

    # HeightMapShape3D has one-meter spacing and is centered on its
    # CollisionShape3D. Fill rows from negative Z to positive Z.
    var data_index := 0
    for z_index in range(map_depth):
        var z_position := float(z_index) - HALF_DEPTH
        for x_index in range(map_width):
            var x_position := float(x_index) - HALF_WIDTH
            height_data[data_index] = _height_at(x_position, z_position)
            data_index += 1
    terrain_shape.map_data = height_data

    var body := StaticBody3D.new()
    body.name = "IslandCollision"
    body.collision_layer = 1
    body.collision_mask = 1

    var collision := CollisionShape3D.new()
    collision.name = "TerrainHeightMap"
    collision.shape = terrain_shape
    body.add_child(collision)
    add_child(body)

func _add_radial_band(island_mesh: ArrayMesh, inner_radius: float, outer_radius: float, ring_count: int, material: Material) -> void:
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
            # At the exact center, the inner edge collapses to one point.
            # Emit only one non-degenerate triangle for that first ring.
            if radius_a > 0.0001:
                surface.add_vertex(inner_a)
                surface.add_vertex(inner_b)
                surface.add_vertex(outer_a)
            surface.add_vertex(inner_b)
            surface.add_vertex(outer_b)
            surface.add_vertex(outer_a)
    surface.generate_normals()
    surface.commit(island_mesh)

func _height_at(x_position: float, z_position: float) -> float:
    var normalized_x := x_position / HALF_WIDTH
    var normalized_z := z_position / HALF_DEPTH
    var radius := sqrt(normalized_x * normalized_x + normalized_z * normalized_z)

    # Keep the height map continuous just outside the visible shoreline.
    # This creates a shallow temporary seabed instead of an infinite fall.
    if radius > OUTER_RADIUS:
        return COLLISION_SEABED_HEIGHT

    if radius <= PLATEAU_RADIUS:
        return MAX_HEIGHT

    var slope_progress := clampf(
        (radius - PLATEAU_RADIUS) / (OUTER_RADIUS - PLATEAU_RADIUS),
        0.0,
        1.0
    )
    var falloff := 1.0 - slope_progress
    var main_height := pow(falloff, 1.55) * MAX_HEIGHT
    var gentle_variation := (
        sin(x_position * 0.13) * cos(z_position * 0.17)
        * 0.25 * falloff * slope_progress
    )
    return maxf(0.0, main_height + gentle_variation)

func _island_vertex(radius: float, angle: float) -> Vector3:
    var x_position := cos(angle) * HALF_WIDTH * radius
    var z_position := sin(angle) * HALF_DEPTH * radius
    return Vector3(x_position, _height_at(x_position, z_position), z_position)

func _make_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

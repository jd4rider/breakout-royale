class_name Models
extends RefCounted
## Loads the Blender-authored models, with a primitive fallback so a missing
## GLB degrades to something visible rather than crashing a run.

const DIR := "res://Assets/Models/props/"

static var _cache: Dictionary = {}


static func has(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".glb")


static func spawn(name: String, tint := Color.WHITE) -> Node3D:
	if not has(name):
		return _fallback(name)
	var packed: PackedScene = _cache.get(name)
	if packed == null:
		packed = load(DIR + name + ".glb")
		_cache[name] = packed
	if packed == null:
		return _fallback(name)
	var node := packed.instantiate() as Node3D
	if tint != Color.WHITE:
		tint_node(node, tint)
	return node


static func _fallback(name: String) -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#8b8fa3")
	var shape: Mesh
	match name:
		"ball":
			var sphere := SphereMesh.new()
			sphere.radius = 0.26
			sphere.height = 0.52
			shape = sphere
			material.emission_enabled = true
			material.emission = Color("#fff2c6")
			material.emission_energy_multiplier = 2.0
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.24
			capsule.height = 0.9
			shape = capsule
		"boss_core":
			var sphere := SphereMesh.new()
			sphere.radius = 1.4
			sphere.height = 2.8
			shape = sphere
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.86, 0.44, 0.4)
			shape = box
	mesh.mesh = shape
	mesh.material_override = material
	root.add_child(mesh)
	return root


## Tints every surface that is not already emissive, preserving the authored
## detail while letting each world and brick type read at a glance. The tinted
## copies are cached: a brick that is destroyed must not free the last
## reference to a material the renderer still has queued for this frame.
static var _tints: Dictionary = {}


static func tint_node(node: Node, color: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface)
			var key := "%d|%d|%s" % [material.get_instance_id() if material != null else 0, surface, color.to_html()]
			var copy: StandardMaterial3D = _tints.get(key)
			if copy == null:
				if material is StandardMaterial3D:
					copy = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
				else:
					copy = StandardMaterial3D.new()
				if copy.emission_enabled and copy.emission_energy_multiplier > 1.4:
					continue
				copy.albedo_color = copy.albedo_color.lerp(color, 0.68)
				_tints[key] = copy
			mesh_instance.set_surface_override_material(surface, copy)


## One shared material per colour keeps the draw calls low and the art
## direction consistent: painted pieces read as solid 3D volumes rather than a
## stack of flat glTF materials.
static var _painted: Dictionary = {}


static func paint(node: Node, color: Color, emission := 0.2) -> void:
	var key := "%s|%.2f" % [color.to_html(), emission]
	var material: StandardMaterial3D = _painted.get(key)
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.38
		material.metallic = 0.3
		material.metallic_specular = 0.65
		if emission > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emission
		_painted[key] = material
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = material


## An emissive material used for generated effects and UI meshes. Cached, so
## a shard that is freed never takes the last reference to a live material with
## it (which makes the GLES backend log "material is null" once a frame).
static var _glow_cache: Dictionary = {}


static func glow_material(color: Color, energy := 2.2) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), energy]
	var cached: StandardMaterial3D = _glow_cache.get(key)
	if cached != null:
		return cached
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_cache[key] = material
	return material

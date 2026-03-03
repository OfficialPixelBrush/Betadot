extends MeshInstance3D

var array_mesh: ArrayMesh

enum Face {
	UP,DOWN,LEFT,RIGHT,FORWARD,BACK
}

var _thread: Thread

func generate_chunk_async(size: Vector3i, data: PackedByteArray) -> void:
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_build_mesh.bind(size, data))

func _build_mesh(size: Vector3i, data: PackedByteArray) -> void:
	# --- Pass 1: count visible faces ---
	var face_count := 0
	for x in range(size.x):
		for z in range(size.z):
			for y in range(size.y):
				var off := Vector3i(x, y, z)
				if _get_block(off, size, data) == 0:
					continue
				if _get_block(off + Vector3i( 0, 1, 0), size, data) == 0: face_count += 1
				if _get_block(off + Vector3i( 0,-1, 0), size, data) == 0: face_count += 1
				if _get_block(off + Vector3i(-1, 0, 0), size, data) == 0: face_count += 1
				if _get_block(off + Vector3i( 1, 0, 0), size, data) == 0: face_count += 1
				if _get_block(off + Vector3i( 0, 0,-1), size, data) == 0: face_count += 1
				if _get_block(off + Vector3i( 0, 0, 1), size, data) == 0: face_count += 1

	# --- Pre-allocate arrays ---
	var verts  := PackedVector3Array(); verts.resize(face_count * 4)
	var norms  := PackedVector3Array(); norms.resize(face_count * 4)
	var uvs    := PackedVector2Array(); uvs.resize(face_count * 4)
	var inds   := PackedInt32Array();   inds.resize(face_count * 6)

	# --- Pass 2: fill arrays ---
	var face_idx := 0
	for x in range(size.x):
		for z in range(size.z):
			for y in range(size.y):
				var off := Vector3i(x, y, z)
				var block = _get_block(off, size, data)
				if block == 0:
					continue
				var ox := float(off.x)
				var oy := float(off.y)
				var oz := float(off.z)
				var textures : Array[Enum.Textures] = _get_block_textures(block)

				if _get_block(off + Vector3i( 0, 1, 0), size, data) == 0:
					face_idx = _write_quad(verts, norms, uvs, inds, face_idx, ox, oy, oz, Face.UP, textures[0])
				if _get_block(off + Vector3i( 0,-1, 0), size, data) == 0:
					face_idx = _write_quad(verts, norms, uvs, inds, face_idx, ox, oy, oz, Face.DOWN, textures[1])
				if _get_block(off + Vector3i(-1, 0, 0), size, data) == 0:
					face_idx = _write_quad(verts, norms, uvs, inds, face_idx, ox, oy, oz, Face.LEFT, textures[2])
				if _get_block(off + Vector3i( 1, 0, 0), size, data) == 0:
					face_idx = _write_quad(verts, norms, uvs, inds, face_idx, ox, oy, oz, Face.RIGHT, textures[3])
				if _get_block(off + Vector3i( 0, 0,-1), size, data) == 0:
					face_idx = _write_quad(verts, norms, uvs, inds, face_idx, ox, oy, oz, Face.FORWARD, textures[4])
				if _get_block(off + Vector3i( 0, 0, 1), size, data) == 0:
					face_idx = _write_quad(verts, norms, uvs, inds, face_idx, ox, oy, oz, Face.BACK, textures[5])

	var built := [verts, norms, uvs, inds]
	call_deferred("_apply_mesh", built)

func _all_sides(texture: Enum.Textures) -> Array[Enum.Textures]:
	return [
		texture,
		texture,
		texture,
		texture,
		texture,
		texture
	]

func _get_block_textures(block : int) -> Array[Enum.Textures]:
	match(block):
		1:
			return _all_sides(Enum.Textures.STONE)
		2:
			return _all_sides(Enum.Textures.GRASS_TOP)
		3:
			return _all_sides(Enum.Textures.DIRT)
		4:
			return _all_sides(Enum.Textures.COBBLESTONE)
		5:
			return _all_sides(Enum.Textures.PLANKS)
		7:
			return _all_sides(Enum.Textures.BEDROCK)
	return [
		Enum.Textures.CRAFTING_TABLE_TOP,
		Enum.Textures.PLANKS,
		Enum.Textures.CRAFTING_TABLE_SIDE,
		Enum.Textures.CRAFTING_TABLE_SIDE,
		Enum.Textures.CRAFTING_TABLE_FRONT,
		Enum.Textures.CRAFTING_TABLE_FRONT
	]

func _apply_mesh(built: Array) -> void:
	if !array_mesh:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh
	array_mesh.clear_surfaces()
	var surface_array: Array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = built[0]
	surface_array[Mesh.ARRAY_NORMAL] = built[1]
	surface_array[Mesh.ARRAY_TEX_UV] = built[2]
	surface_array[Mesh.ARRAY_INDEX]  = built[3]
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	array_mesh.surface_set_material(0,preload("res://Shaders/default_block.tres"))

func _write_quad(
		verts: PackedVector3Array, norms: PackedVector3Array,
		uvs: PackedVector2Array,   inds: PackedInt32Array,
		face_idx: int, ox: float, oy: float, oz: float,
		face: Face,
		texture: Enum.Textures) -> int:

	const texScale := 1.0 / 16.0
	var texX := float(texture % 16) * texScale
	var texY := float(texture / 16) * texScale
	var vi   := face_idx * 4
	var ii   := face_idx * 6

	match face:
		Face.UP:
			verts[vi+0] = Vector3(ox+0.0, oy+0.5, oz+1.0)
			verts[vi+1] = Vector3(ox+1.0, oy+0.5, oz+1.0)
			verts[vi+2] = Vector3(ox+1.0, oy+0.5, oz+0.0)
			verts[vi+3] = Vector3(ox+0.0, oy+0.5, oz+0.0)
			norms[vi+0] = Vector3.UP; norms[vi+1] = Vector3.UP
			norms[vi+2] = Vector3.UP; norms[vi+3] = Vector3.UP
		Face.DOWN:
			verts[vi+0] = Vector3(ox+0.0, oy-0.5, oz+0.0)
			verts[vi+1] = Vector3(ox+1.0, oy-0.5, oz+0.0)
			verts[vi+2] = Vector3(ox+1.0, oy-0.5, oz+1.0)
			verts[vi+3] = Vector3(ox+0.0, oy-0.5, oz+1.0)
			norms[vi+0] = Vector3.DOWN; norms[vi+1] = Vector3.DOWN
			norms[vi+2] = Vector3.DOWN; norms[vi+3] = Vector3.DOWN
		Face.LEFT:
			verts[vi+0] = Vector3(ox+0.0, oy+0.5, oz+0.0)
			verts[vi+1] = Vector3(ox+0.0, oy-0.5, oz+0.0)
			verts[vi+2] = Vector3(ox+0.0, oy-0.5, oz+1.0)
			verts[vi+3] = Vector3(ox+0.0, oy+0.5, oz+1.0)
			norms[vi+0] = Vector3.LEFT; norms[vi+1] = Vector3.LEFT
			norms[vi+2] = Vector3.LEFT; norms[vi+3] = Vector3.LEFT
		Face.RIGHT:
			verts[vi+0] = Vector3(ox+1.0, oy+0.5, oz+1.0)
			verts[vi+1] = Vector3(ox+1.0, oy-0.5, oz+1.0)
			verts[vi+2] = Vector3(ox+1.0, oy-0.5, oz+0.0)
			verts[vi+3] = Vector3(ox+1.0, oy+0.5, oz+0.0)
			norms[vi+0] = Vector3.RIGHT; norms[vi+1] = Vector3.RIGHT
			norms[vi+2] = Vector3.RIGHT; norms[vi+3] = Vector3.RIGHT
		Face.FORWARD:
			verts[vi+0] = Vector3(ox+1.0, oy+0.5, oz+0.0)
			verts[vi+1] = Vector3(ox+1.0, oy-0.5, oz+0.0)
			verts[vi+2] = Vector3(ox+0.0, oy-0.5, oz+0.0)
			verts[vi+3] = Vector3(ox+0.0, oy+0.5, oz+0.0)
			norms[vi+0] = Vector3.FORWARD; norms[vi+1] = Vector3.FORWARD
			norms[vi+2] = Vector3.FORWARD; norms[vi+3] = Vector3.FORWARD
		Face.BACK:
			verts[vi+0] = Vector3(ox+0.0, oy+0.5, oz+1.0)
			verts[vi+1] = Vector3(ox+0.0, oy-0.5, oz+1.0)
			verts[vi+2] = Vector3(ox+1.0, oy-0.5, oz+1.0)
			verts[vi+3] = Vector3(ox+1.0, oy+0.5, oz+1.0)
			norms[vi+0] = Vector3.BACK; norms[vi+1] = Vector3.BACK
			norms[vi+2] = Vector3.BACK; norms[vi+3] = Vector3.BACK
	
	uvs[vi+0] = Vector2(texX+texScale, texY)
	uvs[vi+1] = Vector2(texX+texScale, texY+texScale)
	uvs[vi+2] = Vector2(texX,          texY+texScale)
	uvs[vi+3] = Vector2(texX,          texY)

	inds[ii+0] = vi+0; inds[ii+1] = vi+2; inds[ii+2] = vi+1
	inds[ii+3] = vi+0; inds[ii+4] = vi+3; inds[ii+5] = vi+2

	return face_idx + 1

func _get_block(pos: Vector3i, size: Vector3i, data: PackedByteArray) -> int:
	if pos.x < 0 or pos.x >= size.x: return 0
	if pos.y < 0 or pos.y >= size.y: return 0
	if pos.z < 0 or pos.z >= size.z: return 0
	var index = pos.y + (pos.z * size.y) + (pos.x * size.z * size.y)
	if index < 0 or index >= data.size(): return 0  # safety net
	return data[index]

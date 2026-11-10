extends Node3D
## Procedural thigh-high boot, built from a lofted (swept) leg spine.
## Everything is generated in code: no imported meshes.

const SEGMENTS := 72

# Spine control points, top of the thigh -> pointed toe.
# Y is up, +Z is forward (the toe direction).
var _c_pos := PackedVector3Array([
	Vector3(0.000, 1.000, 0.000),
	Vector3(0.000, 0.900, -0.004),
	Vector3(0.000, 0.780, 0.000),
	Vector3(0.000, 0.690, 0.004),
	Vector3(0.000, 0.590, 0.002),
	Vector3(0.000, 0.470, -0.004),
	Vector3(0.000, 0.350, 0.000),
	Vector3(0.000, 0.255, 0.006),
	Vector3(0.000, 0.215, 0.008),
	Vector3(0.000, 0.188, 0.012),
	Vector3(0.000, 0.150, 0.028),
	Vector3(0.000, 0.100, 0.062),
	Vector3(0.000, 0.068, 0.110),
	Vector3(0.000, 0.050, 0.160),
	Vector3(0.000, 0.040, 0.205),
	Vector3(0.000, 0.040, 0.240),
])
# Half width (lateral, along X)
var _c_rx := PackedFloat32Array([
	0.121, 0.116, 0.103, 0.095, 0.096, 0.106, 0.093, 0.081, 0.073,
	0.068, 0.062, 0.058, 0.058, 0.054, 0.042, 0.016,
])
# Half depth (front-back on the shaft, half height once the spine has turned)
var _c_ry := PackedFloat32Array([
	0.126, 0.120, 0.108, 0.100, 0.102, 0.111, 0.099, 0.087, 0.080,
	0.068, 0.060, 0.054, 0.048, 0.040, 0.030, 0.016,
])
# Superellipse exponent: 2 = ellipse (leg), higher = boxier (sole of the foot)
var _c_sq := PackedFloat32Array([
	2.00, 2.00, 2.05, 2.10, 2.10, 2.05, 2.10, 2.20, 2.30,
	2.70, 3.20, 3.60, 3.80, 3.60, 3.20, 3.00,
])
# How far the rear of the section is pulled back (heel counter / stiletto seat)
var _c_back := PackedFloat32Array([
	0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
	0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
])

var leather: StandardMaterial3D
var gold: StandardMaterial3D
var lining_mat: StandardMaterial3D
var body: MeshInstance3D


func _ready() -> void:
	_make_materials()
	_build_body()
	_build_lining()
	_build_zipper()
	if OS.get_cmdline_user_args().has("--noheel"):
		pass
	else:
		_build_heel()


func set_leather_color(c: Color) -> void:
	leather.albedo_color = c


func set_leather_roughness(v: float) -> void:
	leather.roughness = v


func _make_materials() -> void:
	leather = StandardMaterial3D.new()
	leather.albedo_color = Color(0.045, 0.047, 0.052)
	leather.roughness = 0.32
	leather.metallic = 0.05

	gold = StandardMaterial3D.new()
	gold.albedo_color = Color(0.94, 0.71, 0.30)
	gold.metallic = 1.0
	gold.roughness = 0.24

	lining_mat = StandardMaterial3D.new()
	lining_mat.albedo_color = Color(0.16, 0.10, 0.10)
	lining_mat.roughness = 0.95
	lining_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


# --- curves -------------------------------------------------------------

func _cr_f(a: float, b: float, c: float, d: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (-a + c) * t \
		+ (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 \
		+ (-a + 3.0 * b - 3.0 * c + d) * t3)


func _cr_v(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	return Vector3(
		_cr_f(p0.x, p1.x, p2.x, p3.x, t),
		_cr_f(p0.y, p1.y, p2.y, p3.y, t),
		_cr_f(p0.z, p1.z, p2.z, p3.z, t)
	)


func _seg_index(u: float) -> Array:
	var n := _c_pos.size()
	var f := u * float(n - 1)
	var i := int(floor(f))
	i = clampi(i, 0, n - 2)
	return [i, f - float(i)]


func _sample_at(u: float) -> Dictionary:
	var idx := _seg_index(u)
	var i: int = idx[0]
	var t: float = idx[1]
	var n := _c_pos.size()
	var a := maxi(i - 1, 0)
	var d := mini(i + 2, n - 1)
	return {
		"pos": _cr_v(_c_pos[a], _c_pos[i], _c_pos[i + 1], _c_pos[d], t),
		"rx": _cr_f(_c_rx[a], _c_rx[i], _c_rx[i + 1], _c_rx[d], t),
		"ry": _cr_f(_c_ry[a], _c_ry[i], _c_ry[i + 1], _c_ry[d], t),
		"sq": _cr_f(_c_sq[a], _c_sq[i], _c_sq[i + 1], _c_sq[d], t),
		"back": _cr_f(_c_back[a], _c_back[i], _c_back[i + 1], _c_back[d], t),
	}


## Sample the spine into frames that carry the cross-section orientation.
## Binormal is transported along the curve so the surface does not twist.
func _frames(count: int, from_u := 0.0, to_u := 1.0) -> Array:
	var raw := []
	for i in count:
		var u := lerpf(from_u, to_u, float(i) / float(count - 1))
		raw.append(_sample_at(u))

	var out := []
	var binormal := Vector3.RIGHT
	for i in count:
		var tangent: Vector3
		if i == 0:
			tangent = (raw[1]["pos"] - raw[0]["pos"]).normalized()
		elif i == count - 1:
			tangent = (raw[i]["pos"] - raw[i - 1]["pos"]).normalized()
		else:
			tangent = (raw[i + 1]["pos"] - raw[i - 1]["pos"]).normalized()

		if i > 0:
			var prev: Vector3 = out[i - 1]["t"]
			var q := Quaternion(prev, tangent)
			binormal = (q * binormal).normalized()

		var normal := tangent.cross(binormal).normalized()
		binormal = normal.cross(tangent).normalized()
		out.append({
			"pos": raw[i]["pos"], "t": tangent,
			"b": binormal, "n": normal,
			"rx": raw[i]["rx"], "ry": raw[i]["ry"], "sq": raw[i]["sq"],
			"back": raw[i]["back"],
		})
	return out


func _ring_point(f: Dictionary, ang: float, rx_scale := 1.0, ry_scale := 1.0) -> Vector3:
	var e: float = maxf(f["sq"], 2.0)
	var c := cos(ang)
	var s := sin(ang)
	var px := signf(c) * pow(absf(c), 2.0 / e)
	var py := signf(s) * pow(absf(s), 2.0 / e)
	var b: Vector3 = f["b"]
	var n: Vector3 = f["n"]
	var v: Vector3 = f["pos"] + b * (f["rx"] * px * rx_scale) + n * (f["ry"] * py * ry_scale)
	# Heel counter: pull the rear of the ankle section backwards so the sole has
	# something for the stiletto to grow out of.
	var back: float = f.get("back", 0.0)
	if back > 0.0:
		var rear := clampf((f["pos"].z - v.z) / maxf(float(f["rx"]) * 1.4, 0.001), 0.0, 1.0)
		v.z -= back * rear * rear
	return v


# --- lofted surfaces ----------------------------------------------------

func _loft(frames: Array, reversed := false, rx_scale := 1.0, ry_scale := 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings := frames.size()
	for i in rings:
		for s in SEGMENTS:
			var ang := TAU * float(s) / float(SEGMENTS)
			st.set_uv(Vector2(float(s) / float(SEGMENTS), float(i) / float(rings - 1)))
			st.add_vertex(_ring_point(frames[i], ang, rx_scale, ry_scale))

	for i in rings - 1:
		for s in SEGMENTS:
			var s2 := (s + 1) % SEGMENTS
			var a0 := i * SEGMENTS + s
			var a1 := i * SEGMENTS + s2
			var b0 := (i + 1) * SEGMENTS + s
			var b1 := (i + 1) * SEGMENTS + s2
			if reversed:
				st.add_index(a0); st.add_index(b0); st.add_index(a1)
				st.add_index(a1); st.add_index(b0); st.add_index(b1)
			else:
				st.add_index(a0); st.add_index(a1); st.add_index(b0)
				st.add_index(b0); st.add_index(a1); st.add_index(b1)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _build_body() -> void:
	var frames := _frames(120)
	body = MeshInstance3D.new()
	body.name = "BootBody"
	body.mesh = _loft(frames, true)
	body.material_override = leather
	add_child(body)


## Dark inner shaft so the opening does not show a hollow shell.
func _build_lining() -> void:
	var frames := _frames(48, 0.0, 0.52)
	var inner := []
	for f in frames:
		var c: Dictionary = f.duplicate()
		c["rx"] = float(f["rx"]) * 0.88
		c["ry"] = float(f["ry"]) * 0.88
		inner.append(c)
	var mi := MeshInstance3D.new()
	mi.name = "Lining"
	mi.mesh = _loft(inner, true)
	mi.material_override = lining_mat
	add_child(mi)


# --- zipper -------------------------------------------------------------

func _build_zipper() -> void:
	# Ribbon running down the front of the shaft, from the top opening to the ankle.
	var frames := _frames(150, 0.0, 0.60)
	var half_w := 0.012
	var tape := SurfaceTool.new()
	tape.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_ok := false
	var transforms := []
	var acc := 0.0
	var last_tooth := -1.0

	for i in frames.size():
		var f: Dictionary = frames[i]
		var front: Vector3 = _ring_point(f, PI * 0.5)  # +n side = front of the shaft
		var b: Vector3 = f["b"]
		var n: Vector3 = f["n"]
		var lift := front + n * 0.004
		var l := lift - b * half_w
		var r := lift + b * half_w
		if prev_ok:
			var v0 := float(i - 1) / 20.0
			var v1 := float(i) / 20.0
			tape.set_uv(Vector2(0.0, v0)); tape.add_vertex(prev_l)
			tape.set_uv(Vector2(1.0, v0)); tape.add_vertex(prev_r)
			tape.set_uv(Vector2(0.0, v1)); tape.add_vertex(l)
			tape.set_uv(Vector2(1.0, v1)); tape.add_vertex(r)
			var base := (i - 1) * 4
			tape.add_index(base); tape.add_index(base + 2); tape.add_index(base + 1)
			tape.add_index(base + 2); tape.add_index(base + 3); tape.add_index(base + 1)
			acc += f["pos"].distance_to(frames[i - 1]["pos"])
		prev_l = l
		prev_r = r
		prev_ok = true

		# Teeth are spaced by real arc length, not by ring index.
		if acc - last_tooth >= 0.0060:
			last_tooth = acc
			transforms.append(Transform3D(Basis(b, n, f["t"]), front + n * 0.004))

	tape.generate_normals()
	var tape_mesh := MeshInstance3D.new()
	tape_mesh.name = "ZipperTape"
	tape_mesh.mesh = tape.commit()
	var tape_mat := gold.duplicate()
	tape_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tape_mesh.material_override = tape_mat
	add_child(tape_mesh)

	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.011, 0.0045, 0.0040)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tooth
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ZipperTeeth"
	mmi.multimesh = mm
	mmi.material_override = gold
	add_child(mmi)

	# Slider + pull tab at the top of the zipper.
	var top: Dictionary = frames[0]
	var top_front: Vector3 = _ring_point(top, PI * 0.5) + Vector3(0, 0, 0.004)
	var slider := MeshInstance3D.new()
	var slider_mesh := BoxMesh.new()
	slider_mesh.size = Vector3(0.030, 0.024, 0.011)
	slider.mesh = slider_mesh
	slider.material_override = gold
	slider.transform = Transform3D(Basis(), top_front + Vector3(0, -0.030, 0.004))
	add_child(slider)

	var tab := MeshInstance3D.new()
	var tab_mesh := BoxMesh.new()
	tab_mesh.size = Vector3(0.013, 0.036, 0.005)
	tab.mesh = tab_mesh
	tab.material_override = gold
	tab.transform = Transform3D(Basis(), top_front + Vector3(0, -0.060, 0.006))
	add_child(tab)


# --- heel ---------------------------------------------------------------

func _build_heel() -> void:
	var heel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.017
	mesh.bottom_radius = 0.008
	mesh.height = 0.160
	mesh.radial_segments = 24
	heel.mesh = mesh
	heel.material_override = gold
	# Under the back of the foot, leaning slightly backwards.
	heel.transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(7.0)),
		Vector3(0.0, 0.080, -0.006)
	)
	add_child(heel)

	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.009
	tip_mesh.bottom_radius = 0.007
	tip_mesh.height = 0.014
	tip_mesh.radial_segments = 20
	tip.mesh = tip_mesh
	tip.material_override = gold
	tip.transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(7.0)),
		Vector3(0.0, 0.006, -0.024)
	)
	add_child(tip)


























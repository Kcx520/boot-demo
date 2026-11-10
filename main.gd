extends Node3D
## Boot viewer: orbits the camera, and lets you recolour the leather at runtime.

const BootModelScript := preload("res://boot_model.gd")

const SWATCHES := [
	{"name": "黑", "color": Color(0.045, 0.047, 0.052)},
	{"name": "酒红", "color": Color(0.36, 0.075, 0.115)},
	{"name": "焦糖", "color": Color(0.36, 0.20, 0.10)},
	{"name": "米白", "color": Color(0.88, 0.85, 0.78)},
	{"name": "正红", "color": Color(0.62, 0.05, 0.08)},
	{"name": "雾蓝", "color": Color(0.20, 0.30, 0.42)},
	{"name": "橄榄", "color": Color(0.20, 0.24, 0.16)},
	{"name": "银灰", "color": Color(0.55, 0.57, 0.60)},
]

var boot: Node3D
var cam: Camera3D

var target := Vector3(0.0, 0.42, 0.0)
var yaw := 0.62
var pitch := 0.10
var dist := 1.60

var _color := Color(0.045, 0.047, 0.052)
var _roughness := 0.32
var _shot_mode := false


func _ready() -> void:
	_shot_mode = "--shot" in OS.get_cmdline_user_args()
	_build_environment()
	_build_floor()
	_build_boot()
	_build_camera()
	_build_ui()
	if _shot_mode:
		await _run_shots()


func _build_boot() -> void:
	boot = BootModelScript.new()
	boot.name = "Boot"
	boot.scale = Vector3.ONE * 0.80  # ~80 cm: a real thigh-high boot
	add_child(boot)
	boot.set_leather_color(_color)
	boot.set_leather_roughness(_roughness)


# --- scene --------------------------------------------------------------

func _build_environment() -> void:
	# Flat grey background, but metals are lit by a hidden studio sky so the
	# gold zipper and heel actually read as gold instead of black.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.58, 0.64)
	sky_mat.sky_horizon_color = Color(0.92, 0.92, 0.93)
	sky_mat.ground_horizon_color = Color(0.75, 0.75, 0.77)
	sky_mat.ground_bottom_color = Color(0.45, 0.46, 0.48)
	sky_mat.sun_angle_max = 40.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.80, 0.81, 0.83)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.73, 0.80)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.ssao_enabled = true

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -52.0, 0.0)
	key.light_energy = 2.2
	key.light_color = Color(1.0, 0.97, 0.93)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 12.0
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12.0, 148.0, 0.0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.78, 0.86, 1.0)
	add_child(rim)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(1.0, 0.95, 0.92)
	add_child(fill)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.73, 0.75)
	mat.roughness = 0.55

	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 38.0
	add_child(cam)
	_update_camera()
	cam.current = true


func _update_camera() -> void:
	var dir := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	)
	cam.position = target + dir * dist
	cam.look_at(target)


# --- input --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT and not _shot_mode:
			yaw -= mm.relative.x * 0.008
			pitch = clampf(pitch - mm.relative.y * 0.006, -0.55, 1.15)
			_update_camera()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				dist = clampf(dist - 0.09, 0.6, 4.0)
				_update_camera()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				dist = clampf(dist + 0.09, 0.6, 4.0)
				_update_camera()


# --- ui -----------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	layer.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.88)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "皮革颜色"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.15, 0.16, 0.18))
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	for sw in SWATCHES:
		row.add_child(_make_swatch(sw["color"]))

	var picker := ColorPickerButton.new()
	picker.text = "自定义颜色…"
	picker.custom_minimum_size = Vector2(0, 34)
	picker.color = _color
	picker.edit_alpha = false
	picker.color_changed.connect(_on_color_changed)
	vbox.add_child(picker)

	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 8)
	vbox.add_child(rrow)

	var rlabel := Label.new()
	rlabel.text = "光泽"
	rlabel.add_theme_color_override("font_color", Color(0.15, 0.16, 0.18))
	rrow.add_child(rlabel)

	var slider := HSlider.new()
	slider.min_value = 0.05
	slider.max_value = 0.7
	slider.step = 0.01
	slider.value = _roughness
	slider.custom_minimum_size = Vector2(130, 24)
	slider.value_changed.connect(_on_roughness_changed)
	rrow.add_child(slider)

	var hint := Label.new()
	hint.text = "左键拖动旋转 · 滚轮缩放"
	hint.position = Vector2(20, 0)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.add_theme_color_override("font_color", Color(0.25, 0.26, 0.28))
	layer.add_child(hint)


func _make_swatch(c: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(30, 30)
	b.tooltip_text = "应用此颜色"

	var normal := StyleBoxFlat.new()
	normal.bg_color = c
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = Color(0, 0, 0, 0.25)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.set_border_width_all(2)
	hover.border_color = Color(1, 1, 1, 0.9)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_on_color_changed.bind(c))
	return b


func _on_color_changed(c: Color) -> void:
	_color = c
	if boot:
		boot.set_leather_color(c)


func _on_roughness_changed(v: float) -> void:
	_roughness = v
	if boot:
		boot.set_leather_roughness(v)


# --- offline screenshots ------------------------------------------------

func _run_shots() -> void:
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)

	var angles := [
		{"yaw": 0.62, "pitch": 0.10, "dist": 1.60, "name": "front", "target": Vector3(0, 0.42, 0)},
		{"yaw": 1.52, "pitch": 0.04, "dist": 1.55, "name": "side", "target": Vector3(0, 0.42, 0)},
		{"yaw": 2.45, "pitch": 0.06, "dist": 1.55, "name": "back", "target": Vector3(0, 0.42, 0)},
		{"yaw": 1.05, "pitch": 0.18, "dist": 0.55, "name": "foot", "target": Vector3(0, 0.11, 0.10)},
	]
	for a in angles:
		yaw = a["yaw"]
		pitch = a["pitch"]
		dist = a["dist"]
		target = a["target"]
		_update_camera()
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://shots/boot_%s.png" % a["name"]
		var err := img.save_png(path)
		print("shot %s -> %s" % [path, error_string(err)])

	# Prove the recolour path works: same model, two other leather colours.
	var variants := [
		{"name": "wine", "color": Color(0.34, 0.05, 0.09)},
		{"name": "cream", "color": Color(0.86, 0.82, 0.74)},
	]
	yaw = 0.62
	pitch = 0.10
	dist = 1.60
	target = Vector3(0, 0.42, 0)
	_update_camera()
	for v in variants:
		_on_color_changed(v["color"])
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "res://shots/boot_%s.png" % v["name"]
		print("shot %s -> %s" % [path, error_string(img.save_png(path))])

	get_tree().quit()

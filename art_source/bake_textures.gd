extends SceneTree

const STORE := "res://assets/art/materials/"
const WORKSHOP_TILES := [&"parkerized", &"painted", &"polymer", &"armory"]
const WORKSHOP_NORMAL := [1.18, 1.45, 1.20, 2.02]
const WORKSHOP_ROUGHNESS := [0.50, 0.67, 0.72, 0.86]
const CANYON_TILES := [&"gravel", &"sandstone", &"bunker", &"armor"]
const CANYON_NORMAL := [1.43, 2.23, 1.74, 1.28]
const CANYON_ROUGHNESS := [0.92, 0.89, 0.82, 0.68]

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] in ["--field-atlas", "--workshop-atlas", "--canyon-atlas"]:
		var textures := Image.load_from_file(arguments[1])
		if textures == null or textures.is_empty():
			printerr("Could not decode the texture atlas.")
			quit(1)
			return
		if arguments[0] == "--workshop-atlas":
			_bake_atlas(textures, "", WORKSHOP_TILES, WORKSHOP_NORMAL, WORKSHOP_ROUGHNESS)
		elif arguments[0] == "--canyon-atlas":
			_bake_atlas(textures, "canyon_", CANYON_TILES, CANYON_NORMAL, CANYON_ROUGHNESS)
		else:
			_bake_tile(textures, 3, "field_alloy", 1.16)
		quit()
		return
	if arguments.size() == 1:
		var daylight := Image.load_from_file(arguments[0])
		if daylight == null or daylight.is_empty():
			printerr("Could not decode the daytime panorama.")
			quit(1)
			return
		_panorama(daylight)
		quit()
		return
	printerr("Provide a panorama image or an atlas with --field-atlas, --workshop-atlas or --canyon-atlas.")
	quit(2)

func _bake_atlas(atlas: Image, prefix: String, names: Array, strengths: Array, roughness: Array) -> void:
	for index in range(names.size()):
		_bake_tile(atlas, index, prefix + String(names[index]), strengths[index], roughness[index])

func _bake_tile(atlas: Image, index: int, filename: String, normal_strength: float, roughness := -1.0) -> void:
	var half := atlas.get_size() / 2
	var inset := Vector2i(12, 12)
	var origin := Vector2i(index % 2 * half.x, (index >> 1) * half.y)
	var tile := atlas.get_region(Rect2i(origin + inset, half - inset * 2))
	tile.convert(Image.FORMAT_RGB8)
	tile.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	_match_edges(tile, false, 29)
	_match_edges(tile, true, 29)
	var normals := tile.duplicate()
	normals.bump_map_to_normal_map(normal_strength)
	_save(normals, filename + "_normal.png")
	if roughness >= 0.0:
		_save(_roughness_map(tile, roughness), filename + "_roughness.png")
	if filename == "field_alloy":
		for y in range(tile.get_height()):
			for x in range(tile.get_width()):
				tile.set_pixel(x, y, tile.get_pixel(x, y).lerp(Color.WHITE, 0.55))
	_save(tile, filename + ".jpg")

func _roughness_map(albedo: Image, baseline: float) -> Image:
	var result := Image.create_empty(albedo.get_width(), albedo.get_height(), false, Image.FORMAT_L8)
	var average: Image = albedo.duplicate()
	average.resize(1, 1, Image.INTERPOLATE_TRILINEAR)
	var middle := average.get_pixel(0, 0).get_luminance()
	for y in range(albedo.get_height()):
		for x in range(albedo.get_width()):
			var value := albedo.get_pixel(x, y).get_luminance()
			var grain := clampf(baseline + (middle - value) * 1.27, 0.25, 0.96)
			result.set_pixel(x, y, Color(grain, grain, grain))
	return result

func _panorama(image: Image) -> void:
	image.convert(Image.FORMAT_RGB8)
	image.resize(1536, 768, Image.INTERPOLATE_LANCZOS)
	_match_edges(image, false, 74)
	_save(image, "day_panorama.jpg")

func _match_edges(image: Image, vertical: bool, width: int) -> void:
	var depth := image.get_height() if vertical else image.get_width()
	var length := image.get_width() if vertical else image.get_height()
	for near in range(width):
		var weight := 0.5 * (1.0 - smoothstep(0.0, float(width), float(near)))
		for across in range(length):
			var a := Vector2i(across, near) if vertical else Vector2i(near, across)
			var b := Vector2i(across, depth - 1 - near) if vertical else Vector2i(depth - 1 - near, across)
			var left := image.get_pixelv(a)
			var right := image.get_pixelv(b)
			image.set_pixelv(a, left.lerp(right, weight))
			image.set_pixelv(b, right.lerp(left, weight))

func _save(image: Image, filename: String) -> void:
	var status := image.save_jpg(STORE + filename, 0.92) if filename.ends_with(".jpg") else image.save_png(STORE + filename)
	if status != OK:
		printerr("Could not bake ", filename, " (", status, ")")
		quit(1)
	else:
		print("BAKED ", filename, " ", image.get_size())

class_name AsterMapNotes
extends RefCounted

const VERSION := 1
const VECTOR_FIELDS := ["position", "normal", "camera_position", "camera_rotation_degrees"]

var path: String
var notes: Array[Dictionary] = []
var _stored_text := ""
var _has_file := false

func _init(notebook_path := "") -> void:
	path = notebook_path
	if path.is_empty():
		path = ProjectSettings.globalize_path("res://.tools/map_notes.json" if OS.has_feature("editor") else "user://map_notes.json")

func load_notes() -> Error:
	if not FileAccess.file_exists(path):
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var contents := file.get_as_text()
	var data: Variant = JSON.parse_string(contents)
	if not data is Dictionary or data.get("version") != VERSION or not data.get("notes") is Array:
		return ERR_FILE_CORRUPT
	var loaded: Array[Dictionary] = []
	for entry: Variant in data.notes:
		if not entry is Dictionary or not entry.get("comment") is String:
			return ERR_FILE_CORRUPT
		for field in VECTOR_FIELDS:
			var vector: Variant = entry.get(field)
			if not vector is Dictionary:
				return ERR_FILE_CORRUPT
			for axis in ["x", "y", "z"]:
				var component: Variant = vector.get(axis)
				if not (component is float or component is int) or not is_finite(float(component)):
					return ERR_FILE_CORRUPT
			entry[field] = Vector3(vector.x, vector.y, vector.z)
		loaded.append(entry)
	notes = loaded
	_stored_text = contents
	_has_file = true
	return OK

func save_note(index: int, note: Dictionary) -> Error:
	if FileAccess.file_exists(path) != _has_file or (_has_file and FileAccess.get_file_as_string(path) != _stored_text):
		return ERR_BUSY
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var updated: Array[Dictionary] = notes.duplicate()
	if index == notes.size():
		updated.append(note)
	else:
		updated[index] = note
	var entries: Array[Dictionary] = []
	for current: Dictionary in updated:
		var entry := current.duplicate()
		for field in VECTOR_FIELDS:
			var value: Vector3 = entry[field]
			entry[field] = {"x": value.x, "y": value.y, "z": value.z}
		entries.append(entry)
	var contents := JSON.stringify({"version": VERSION, "notes": entries}, "\t", false, true) + "\n"
	var temporary := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return error
	notes = updated
	_stored_text = contents
	_has_file = true
	return OK

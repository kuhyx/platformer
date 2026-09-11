class_name SaveFile
extends RefCounted
## Invisible autosave (D03): room id + registry hash, atomically written
## (temp + rename) to the user-data dir. On web, user:// is IndexedDB.
## Missing or corrupt → start fresh, silently (D19).

const PATH := "user://save.json"
const TMP := "user://save.json.tmp"


static func write(room_id: int) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open %s" % TMP)
		return
	f.store_string(JSON.stringify({"room_id": room_id, "params_hash": Params.registry_hash()}))
	f.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TMP), ProjectSettings.globalize_path(PATH)
	)
	if err != OK:
		push_warning("save: rename failed (%d)" % err)


## The saved room id when it is a valid index, else 0.
static func read_room(room_count: int) -> int:
	if not FileAccess.file_exists(PATH):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary) or not parsed.has("room_id"):
		return 0
	var id: Variant = parsed["room_id"]
	if not (id is float) or int(id) < 0 or int(id) >= room_count:
		return 0
	return int(id)

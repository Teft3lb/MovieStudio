extends RefCounted
class_name FilmScriptData

const SCHEMA_VERSION: int = 1

var id: String = ""
var title: String = ""
var genre_id: String = ""
var genre_title: String = ""
var logline: String = ""
var writer_id: String = ""
var writer_name: String = ""
var scene_count: int = 0
var role_count: int = 0
var potential_score: int = 0
var potential_stars: int = 1
var popularity_modifier: float = 1.0
var cast: Array = []
var scenes: Array = []


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"title": title,
		"genre_id": genre_id,
		"genre_title": genre_title,
		"logline": logline,
		"writer_id": writer_id,
		"writer_name": writer_name,
		"scene_count": scene_count,
		"role_count": role_count,
		"potential_score": potential_score,
		"potential_stars": potential_stars,
		"popularity_modifier": popularity_modifier,
		"cast": cast.duplicate(true),
		"scenes": scenes.duplicate(true),
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var result: Variant = load(
		"res://scripts/domain/script_department/film_script_data.gd"
	).new()
	result.id = str(payload.get("id", ""))
	result.title = str(payload.get("title", ""))
	result.genre_id = str(payload.get("genre_id", ""))
	result.genre_title = str(payload.get("genre_title", ""))
	result.logline = str(payload.get("logline", ""))
	result.writer_id = str(payload.get("writer_id", ""))
	result.writer_name = str(payload.get("writer_name", ""))
	result.scene_count = clampi(int(payload.get("scene_count", 0)), 0, 100)
	result.role_count = clampi(int(payload.get("role_count", 0)), 0, 100)
	result.potential_score = clampi(int(payload.get("potential_score", 0)), 0, 100)
	result.potential_stars = clampi(int(payload.get("potential_stars", 1)), 1, 5)
	result.popularity_modifier = clampf(
		float(payload.get("popularity_modifier", 1.0)),
		0.5,
		1.5
	)
	var raw_cast: Variant = payload.get("cast", [])
	if raw_cast is Array:
		result.cast = raw_cast.duplicate(true)
	var raw_scenes: Variant = payload.get("scenes", [])
	if raw_scenes is Array:
		result.scenes = raw_scenes.duplicate(true)
	return result

extends "res://tests/smoke_test_base.gd"

const DOSSIER_SCRIPT = preload(
	"res://scripts/domain/film_production/film_production_dossier.gd"
)
const DOSSIER_ACTOR_SCRIPT = preload(
	"res://scripts/presentation/studio/studio_film_dossier_actor.gd"
)


class TestScript extends RefCounted:
	var id: String = "SCR-DOSSIER-01"
	var title: String = "Золотой кадр"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var dossier: RefCounted = DOSSIER_SCRIPT.new()
	dossier.call("setup", TestScript.new(), "BLD-SCRIPT")
	_expect(
		str(dossier.phase) == "at_writers"
		and bool(dossier.call("is_movable")),
		"Written screenplay must be a physical transferable production dossier."
	)
	_expect(
		not bool(dossier.call("deliver_to_building", "editing_suite", "BLD-EDIT")),
		"An unfilmed screenplay must not enter post-production."
	)
	_expect(
		bool(dossier.call("deliver_to_building", "sound_stage", "BLD-STAGE"))
		and not bool(dossier.call("is_movable")),
		"Screenplay must first be delivered to the sound stage."
	)
	_expect(
		not bool(dossier.call("finish_production"))
		and bool(dossier.call("start_production")),
		"Production cannot finish before filming has begun."
	)
	_expect(
		not bool(dossier.call("deliver_to_building", "editing_suite", "BLD-EDIT"))
		and bool(dossier.call("finish_production")),
		"Footage only becomes transferable after completed filming."
	)
	_expect(
		bool(dossier.call("deliver_to_building", "editing_suite", "BLD-EDIT"))
		and bool(dossier.call("start_editing")),
		"Footage must be delivered to editing before editing can begin."
	)
	_expect(
		not bool(dossier.call("release_film"))
		and bool(dossier.call("finish_editing")),
		"Unfinished edits cannot be released as a mastered film."
	)
	_expect(
		bool(dossier.call("release_film"))
		and not bool(dossier.call("is_movable"))
		and not bool(dossier.call("release_film")),
		"Master must be released exactly once."
	)

	var actor: Node3D = DOSSIER_ACTOR_SCRIPT.new()
	var screenplay: RefCounted = DOSSIER_SCRIPT.new()
	screenplay.call("setup", TestScript.new(), "BLD-SCRIPT")
	actor.call("setup", screenplay)
	root.add_child(actor)
	_expect(
		actor.get_node_or_null("DossierHitbox/CollisionShape3D") != null
		and actor.get_node_or_null("DocumentVisual/ScreenplayCover") != null
		and actor.is_in_group("film_dossier"),
		"World screenplay must have visible 3D geometry and an independently clickable hitbox."
	)
	screenplay.call("deliver_to_building", "sound_stage", "BLD-STAGE")
	screenplay.call("start_production")
	screenplay.call("finish_production")
	actor.call("refresh_appearance")
	_expect(
		actor.get_node_or_null("DocumentVisual/FilmReelLeft") != null
		and actor.get_node_or_null("DocumentVisual/ScreenplayCover") == null,
		"Completed shooting must turn the dossier visual into a physical film reel."
	)
	actor.free()
	_finish_test("FilmProductionDossierSmokeTest")

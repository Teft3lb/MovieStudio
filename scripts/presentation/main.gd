extends Node3D

@onready var game_clock: GameClock = $GameClock
@onready var studio_hud: Node = $StudioHUD
@onready var character_manager: Node = $CharacterManager
@onready var studio_building_manager: Node = $StudioBuildingManager


func _ready() -> void:
	studio_hud.call("setup", game_clock)
	studio_building_manager.call("setup", game_clock, character_manager)
	studio_building_manager.call("ensure_startup_content")
	character_manager.call(
		"initialize_workplaces",
		studio_building_manager
	)
	studio_hud.call("hide_workspace_drawer")
	studio_hud.call("show_inspector_panel", "", false)
	if not bool(studio_building_manager.call("is_startup_content_ready")):
		push_error(
			"MovieStudio startup: initial buildings or building workspaces are missing."
		)

extends Node3D

@onready var game_clock: GameClock = $GameClock
@onready var studio_hud: Node = $StudioHUD
@onready var character_manager: Node = $CharacterManager
@onready var studio_building_manager: Node = $StudioBuildingManager


func _ready() -> void:
	studio_hud.call("setup", game_clock)
	studio_building_manager.call("setup", game_clock, character_manager)
	character_manager.call(
		"initialize_workplaces",
		studio_building_manager
	)
	studio_hud.call("show_workspace_panel", "studio")
	studio_hud.call("show_inspector_panel", "", false)

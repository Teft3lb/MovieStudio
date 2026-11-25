extends RefCounted

const MAX_DISTANCE_SQUARED: float = 5.5 * 5.5

var _active: Dictionary[String, WeakRef] = {}


func update(cohorts: Dictionary, actors: Dictionary, absolute_minute: int) -> void:
	var next: Dictionary[String, WeakRef] = {}
	var exchange := floori(float(absolute_minute) / 3.0)
	if exchange % 3 != 2:
		for attendees in cohorts.values():
			for first_index in attendees.size():
				var first: Variant = attendees[first_index]
				var first_id: String = str(first.id)
				var first_actor := actors.get(first_id) as CharacterActor
				if first_actor == null or next.has(first_id):
					continue
				var partner_index := _choose_partner(attendees, first_index, first_actor, actors, next)
				if partner_index < 0:
					continue
				var second: Variant = attendees[partner_index]
				var second_id: String = str(second.id)
				var second_actor := actors.get(second_id) as CharacterActor
				var argument: bool = float(first.relationships.get(second_id, 0.0)) < -25.0
				var first_speaks: bool = (exchange + first_id.hash()) % 2 == 0
				first_actor.set_lounge_conversation(second_actor.global_position, first_speaks, argument)
				second_actor.set_lounge_conversation(first_actor.global_position, not first_speaks, argument)
				next[first_id] = weakref(first_actor)
				next[second_id] = weakref(second_actor)
	for employee_id in _active:
		if not next.has(employee_id):
			var actor := _active[employee_id].get_ref() as CharacterActor
			if actor != null:
				actor.clear_lounge_conversation()
	_active = next


func _choose_partner(
	attendees: Array, first_index: int, first_actor: CharacterActor,
	actors: Dictionary, assigned: Dictionary
) -> int:
	var first: Variant = attendees[first_index]
	var best_index: int = -1
	var best_score: float = -INF
	for index in range(first_index + 1, attendees.size()):
		var other: Variant = attendees[index]
		var other_id: String = str(other.id)
		var other_actor := actors.get(other_id) as CharacterActor
		if other_actor == null or assigned.has(other_id):
			continue
		var distance := first_actor.global_position.distance_squared_to(other_actor.global_position)
		if distance <= 0.01 or distance > MAX_DISTANCE_SQUARED:
			continue
		var sociability := (
			float(first.personality.get("sociability", 0.5))
			+ float(other.personality.get("sociability", 0.5))
		) * 0.5
		var stress := maxf(float(first.needs.get("stress", 0.0)), float(other.needs.get("stress", 0.0)))
		if sociability - stress * 0.25 < 0.28:
			continue
		var rapport := float(first.relationships.get(other_id, 0.0))
		var score := (absf(rapport) * 0.02 + sociability) - distance * 0.045
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

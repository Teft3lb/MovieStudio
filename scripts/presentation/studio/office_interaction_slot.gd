extends Node3D
class_name OfficeInteractionSlot

var slot_id: String
var left_hand: Marker3D
var right_hand: Marker3D
var _occupant: WeakRef


func setup(building_id: String, index: int, seat: Vector3, keyboard: Vector3) -> void:
	slot_id = "%s/office/%d" % [building_id, index]
	name = "Workstation_%d" % index
	position = seat
	_add_marker("Approach", Vector3(0.60, 0.0, 0.38))
	_add_marker("Seat", Vector3.UP * 0.535)
	_add_marker("LeftFoot", Vector3(-0.14, 0.025, -0.44))
	_add_marker("RightFoot", Vector3(0.14, 0.025, -0.44))
	left_hand = _add_marker("LeftHand", keyboard - seat + Vector3(-0.155, 0.065, 0.035))
	right_hand = _add_marker("RightHand", keyboard - seat + Vector3(0.155, 0.065, 0.035))


func try_reserve(actor: Node3D) -> bool:
	var occupant := get_occupant()
	if occupant != null and occupant != actor:
		return false
	_occupant = weakref(actor)
	return true


func release(actor: Node3D) -> void:
	if get_occupant() == actor:
		_occupant = null


func get_occupant() -> Node3D:
	return _occupant.get_ref() as Node3D if _occupant != null else null


func _add_marker(marker_name: String, location: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = location
	add_child(marker)
	return marker

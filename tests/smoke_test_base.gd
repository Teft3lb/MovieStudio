extends SceneTree

var _failures: Array[String] = []


func _expect(condition: bool, message: String = "Assertion failed.") -> void:
	if condition:
		return
	_failures.append(message)
	push_error("ASSERTION FAILED: %s" % message)


func _finish_test(test_name: String) -> void:
	if _failures.is_empty():
		print("%s: PASS" % test_name)
		quit(0)
		return

	printerr(
		"%s: FAIL (%d assertion(s))" % [
			test_name,
			_failures.size(),
		]
	)
	for failure in _failures:
		printerr(" - %s" % failure)
	quit(1)

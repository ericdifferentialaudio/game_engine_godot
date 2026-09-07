extends GutTest
## Sanity tests for the VirtueSystem autoload. Also serves as the smoke
## test that proves the GUT harness itself is wired up correctly.


func before_each() -> void:
	VirtueSystem.reset()


func test_get_virtue_defaults_to_zero() -> void:
	assert_eq(VirtueSystem.get_virtue(&"honesty"), 0.0)


func test_set_virtue_updates_value() -> void:
	VirtueSystem.set_virtue(&"honesty", 10.0)
	assert_eq(VirtueSystem.get_virtue(&"honesty"), 10.0)


func test_set_virtue_emits_virtue_changed_signal() -> void:
	watch_signals(VirtueSystem)
	VirtueSystem.set_virtue(&"courage", 5.0)
	assert_signal_emitted_with_parameters(
		VirtueSystem, "virtue_changed", [&"courage", 0.0, 5.0]
	)


func test_set_virtue_same_value_does_not_emit_signal() -> void:
	VirtueSystem.set_virtue(&"courage", 5.0)
	watch_signals(VirtueSystem)
	VirtueSystem.set_virtue(&"courage", 5.0)
	assert_signal_not_emitted(VirtueSystem, "virtue_changed")

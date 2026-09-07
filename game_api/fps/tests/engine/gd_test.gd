## Base class for in-engine test suites. Extend, write `test_*` methods, use
## the assert_* helpers. Nodes created via `spawn()` are freed after each test.
class_name GdTest
extends RefCounted

var tree: SceneTree
var errors: Array[String] = []
var _spawned: Array[Node] = []


func _reset() -> void:
	errors.clear()


func before_each() -> void:
	pass


func after_each() -> void:
	free_all()


func free_all() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


## Add a node to the tree root for the duration of the test.
func spawn(node: Node) -> Node:
	tree.root.add_child(node)
	_spawned.append(node)
	return node


## Create a bare Actor with all components and the given definition id.
func make_actor(def_id: String = "", with_brain: bool = false) -> Actor:
	var a := Actor.new()
	a.actor_def_id = def_id
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	a.add_child(shape)
	if with_brain:
		a.add_child(AIBrain.new())
	spawn(a)
	return a


# --- Assertions --------------------------------------------------------------

func fail(msg: String) -> void:
	errors.append(msg)


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		fail("%sexpected %s, got %s" % [msg + ": " if msg != "" else "", str(expected), str(actual)])


func assert_ne(actual, unexpected, msg: String = "") -> void:
	if actual == unexpected:
		fail("%sexpected something other than %s" % [msg + ": " if msg != "" else "", str(unexpected)])


func assert_approx(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("%sexpected ~%s, got %s" % [msg + ": " if msg != "" else "", str(expected), str(actual)])


func assert_gt(actual: float, threshold: float, msg: String = "") -> void:
	if not actual > threshold:
		fail("%sexpected > %s, got %s" % [msg + ": " if msg != "" else "", str(threshold), str(actual)])


func assert_lt(actual: float, threshold: float, msg: String = "") -> void:
	if not actual < threshold:
		fail("%sexpected < %s, got %s" % [msg + ": " if msg != "" else "", str(threshold), str(actual)])


func assert_not_null(v, msg: String = "expected non-null") -> void:
	if v == null:
		fail(msg)


func assert_null(v, msg: String = "expected null") -> void:
	if v != null:
		fail(msg)


func assert_has(container, key, msg: String = "") -> void:
	if not (key in container):
		fail("%sexpected to contain %s" % [msg + ": " if msg != "" else "", str(key)])

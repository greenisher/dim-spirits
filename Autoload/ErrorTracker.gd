extends Node

## ErrorTracker - Global Error Detection Script
## This will help us find the EXACT source of basis invert errors
##
## INSTALLATION:
## 1. Save this as error_tracker.gd
## 2. Go to Project -> Project Settings -> Autoload
## 3. Add this script with name "ErrorTracker"
## 4. Run game
## 5. Check console when error occurs

var _frame_count := 0
var _last_error_frame := -1

func _ready():
	print("=== ErrorTracker initialized ===")
	print("Watching for basis invert errors...")
	
func _process(_delta):
	_frame_count += 1

func _physics_process(_delta):
	# Check all nodes in the scene tree for invalid transforms
	_check_scene_tree()

func _check_scene_tree():
	# Only check every 60 frames to avoid performance hit
	if _frame_count % 60 != 0:
		return
	
	var root = get_tree().root
	_check_node_recursive(root)

func _check_node_recursive(node: Node):
	# Skip if not a 3D node
	if not (node is Node3D):
		_check_children(node)
		return
	
	var node3d = node as Node3D
	
	# Check scale
	if node3d.scale.x == 0 or node3d.scale.y == 0 or node3d.scale.z == 0:
		_report_issue(node3d, "ZERO SCALE")
	
	# Check determinant
	var det = node3d.global_transform.basis.determinant()
	if abs(det) < 0.0001:
		_report_issue(node3d, "ZERO DETERMINANT")
	
	_check_children(node)

func _check_children(node: Node):
	for child in node.get_children():
		_check_node_recursive(child)

func _report_issue(node: Node3D, issue_type: String):
	# Only report once per frame to avoid spam
	if _last_error_frame == _frame_count:
		return
	_last_error_frame = _frame_count
	
	print("\n" + "=".repeat(60))
	print("⚠️ TRANSFORM ISSUE DETECTED!")
	print("=".repeat(60))
	print("Issue Type: ", issue_type)
	print("Node Name: ", node.name)
	print("Node Type: ", node.get_class())
	print("Node Path: ", node.get_path())
	print("Position: ", node.global_position)
	print("Rotation: ", node.rotation_degrees)
	print("Scale: ", node.scale)
	print("Parent: ", node.get_parent().name if node.get_parent() else "None")
	
	# Print script if it has one
	var script = node.get_script()
	if script:
		print("Script: ", script.resource_path)
	
	# Print the determinant
	var det = node.global_transform.basis.determinant()
	print("Determinant: ", det)
	
	print("=".repeat(60) + "\n")
	
	# Try to get stack trace
	print("Call Stack:")
	var stack = get_stack()
	for i in range(min(5, stack.size())):
		var frame = stack[i]
		print("  [%d] %s : %s() : line %d" % [i, frame.source, frame.function, frame.line])
	print()

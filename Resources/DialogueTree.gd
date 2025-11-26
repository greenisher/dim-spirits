extends Resource
class_name DialogueTree

@export var dialogue_nodes: Array[Resource] = []  # Array of DialogueNode resources
@export var start_node_id: String = "start"

func get_node_by_id(node_id: String) -> Resource:
	for node in dialogue_nodes:
		if node.get("id") == node_id:
			return node
	return null

func get_start_node() -> Resource:
	var start = get_node_by_id(start_node_id)
	if start:
		return start
	
	# Otherwise return first node
	if dialogue_nodes.size() > 0:
		return dialogue_nodes[0]
	
	return null

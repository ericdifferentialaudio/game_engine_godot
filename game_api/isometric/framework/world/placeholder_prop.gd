## Blockout stand-in for any missing site/structure scene: a coloured marker
## with a label. AssetRegistry falls back to this so data-only games run.
extends Node2D

@onready var _label: Label = $Label
@onready var _marker: Polygon2D = $Marker


func configure(text: String, color: Color) -> void:
	if not is_node_ready():
		await ready
	_label.text = text
	_marker.color = color

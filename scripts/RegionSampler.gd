extends Reference

class_name RegionSampler

const RegionType = preload("res://scripts/RegionType.gd").RegionType

var region_type
var specific_areas : Array

var min_x : int
var min_y : int
var max_x : int
var max_y : int

var _map

func _init() -> void:
	pass

func setup(region_type, specific_areas : Array) -> void:
	_map = State.map

	self.region_type = region_type
	self.specific_areas = specific_areas

	match region_type:
		RegionType.HOR_TOP:
			min_x = 0
			min_y = 0
			max_x = _map.width
			max_y = _map.height * 0.25
		RegionType.HOR_BOTTOM:
			min_x = 0
			min_y = _map.height * 0.75
			max_x = _map.width
			max_y = _map.height
		RegionType.VER_LEFT:
			min_x = 0
			min_y = 0
			max_x = _map.width * 0.25
			max_y = _map.height
		RegionType.VER_RIGHT:
			min_x = _map.width * 0.75
			min_y = 0
			max_x = _map.width
			max_y = _map.height
		RegionType.HOR_CENTER:
			min_x = 0
			min_y = _map.height * 0.25
			max_x = _map.width
			max_y = _map.height * 0.75
		RegionType.VER_CENTER:
			min_x = _map.width * 0.25
			min_y = 0
			max_x = _map.width * 0.75
			max_y = _map.height

		RegionType.SINGLE_TOP:
			min_x = _map.width * 0.25
			min_y = 0
			max_x = _map.width * 0.75
			max_y = _map.height * 0.25
		RegionType.SINGLE_BOTTOM:
			min_x = _map.width * 0.25
			min_y = _map.height * 0.75
			max_x = _map.width * 0.75
			max_y = _map.height
		RegionType.SINGLE_LEFT:
			min_x = 0
			min_y = _map.height * 0.25
			max_x = _map.width * 0.25
			max_y = _map.height * 0.75
		RegionType.SINGLE_RIGHT:
			min_x = _map.width * 0.75
			min_y = _map.height * 0.25
			max_x = _map.width
			max_y = _map.height * 0.75
		RegionType.SINGLE_CENTER:
			min_x = _map.width * 0.25
			min_y = _map.height * 0.25
			max_x = _map.width * 0.75
			max_y = _map.height * 0.75
		RegionType.SINGLE_TOP_LEFT:
			min_x = 0
			min_y = 0
			max_x = _map.width * 0.25
			max_y = _map.height * 0.25
		RegionType.SINGLE_TOP_RIGHT:
			min_x = _map.width * 0.75
			min_y = 0
			max_x = _map.width
			max_y = _map.height * 0.25
		RegionType.SINGLE_BOTTOM_LEFT:
			min_x = 0
			min_y = _map.height * 0.75
			max_x = _map.width * 0.25
			max_y = _map.height
		RegionType.SINGLE_BOTTOM_RIGHT:
			min_x = _map.width * 0.75
			min_y = _map.height * 0.75
			max_x = _map.width
			max_y = _map.height

		_:
			assert(region_type == RegionType.ALL || region_type == RegionType.SPECIFIC_AREAS)
			min_x = 0
			min_y = 0
			max_x = _map.width
			max_y = _map.height

	# Beware max-value is EXLUSIVE, but that's ok if we use
	# modulo thereafter. But if we don't, we need to substract 1!
	# Example for 32x32 map:
	# min_x = 2, max_x = 30
	# value = min_x + randi() % (max_x - min_x) = 2 + randi() % 28
	# In this case, the maximum value is: 2 + 27 = 29

	min_x = clamp(min_x, 2, _map.width - 2)
	max_x = clamp(max_x, 2, _map.width - 2)

	min_y = clamp(min_y, 2, _map.height - 2)
	max_y = clamp(max_y, 2,_map.height - 2)


func set_random_position(area) -> void:
	if region_type != RegionType.SPECIFIC_AREAS:
		area.set_position(
			min_x + randi() % (max_x - min_x),
			min_y + randi() % (max_y - min_y))
	else:
		assert(specific_areas.size() > 0)

		var specific_area
		if specific_areas.size() == 1:
			specific_area = specific_areas[0]
		else:
			specific_area = specific_areas[randi() % specific_areas.size()]
		if specific_area.get_class() == "WorldCircle":
			# Evenly sample point inside circle
			var r = (specific_area.radius - 1) * sqrt(randf())
			var a = randf() * 2.0 * PI
			area.set_position(
				clamp(int(specific_area.center_x + r * cos(a)), min_x, max_x - 1),
				clamp(int(specific_area.center_y + r * sin(a)), min_y, max_y - 1))
		else:
			area.set_position(
				specific_area.x + randi() % specific_area.width,
				specific_area.y + randi() % specific_area.height)

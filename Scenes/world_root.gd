extends Node3D

var playerEntity = preload("res://Scenes/player_entity.tscn")
@onready var grid_map: GridMap = $GridMap
@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
var skyMat : ProceduralSkyMaterial;

const lengthOfDay : int = 24000;

@export var dayColor : Color;
@export var sunsetColor : Color;
@export var nightColor : Color;

var entities = {}
var time : float = 0.0;
var dayProgress : float = 0;
var dayProgressPercent : float = 0;

func AddEntity(entityId : int):
	var pe = playerEntity.instantiate()
	#print("Adding entity:", entityId)
	entities[entityId] = pe
	#print("Before adding child:", pe, pe.is_inside_tree())
	add_child(pe)
	#print("After adding child:", pe, pe.is_inside_tree())
	#print("Entity added:", pe)

func GetEntity(entityId : int):
	if (entities.has(entityId)):
		return entities[entityId]
	return null

func RemoveEntity(entityId : int):
	if (entities.has(entityId)):
		entities[entityId].queue_free()
		entities.erase(entityId)

func _ready() -> void:
	skyMat = world_environment.environment.sky.sky_material
	pass

func UpdateSky():
	# 0.0 = sunrise
	# 0.25 = midday
	# 0.5 = sunset
	# 0.75 = midnightvar color: Color
	var color: Color
	if dayProgressPercent < 0.1:
		# Sunrise transition: sunsetColor -> dayColor
		color = sunsetColor.lerp(dayColor, dayProgressPercent / 0.1)
	elif dayProgressPercent < 0.4:
		# Day: hold dayColor
		color = dayColor
	elif dayProgressPercent < 0.5:
		# Sunset transition: dayColor -> sunsetColor
		color = dayColor.lerp(sunsetColor, (dayProgressPercent - 0.4) / 0.1)
	elif dayProgressPercent < 0.6:
		# Evening: hold sunsetColor
		color = sunsetColor
	elif dayProgressPercent < 0.7:
		# Night transition: sunsetColor -> nightColor
		color = sunsetColor.lerp(nightColor, (dayProgressPercent - 0.6) / 0.1)
	elif dayProgressPercent < 0.9:
		# Night: hold nightColor
		color = nightColor
	else:
		# Dawn transition: nightColor -> sunrise (sunsetColor)
		color = nightColor.lerp(sunsetColor, (dayProgressPercent - 0.9) / 0.1)


	skyMat.sky_top_color = color
	skyMat.sky_horizon_color = color*2.0
	skyMat.ground_horizon_color = color / 2.0
	skyMat.ground_bottom_color = skyMat.ground_horizon_color
	world_environment.environment.sky.sky_material = skyMat
	pass
	
func UpdateTime(t : int):
	dayProgress = float(t % lengthOfDay)

func _process(delta: float) -> void:
	dayProgressPercent = dayProgress/float(lengthOfDay);
	sun.rotation_degrees.x = 180.0 + dayProgressPercent * 360;
	dayProgress += delta*20.0
	dayProgress = fmod(dayProgress, float(lengthOfDay))
	UpdateSky()

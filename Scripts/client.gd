extends Node

@onready var player: Node3D = $Player
@onready var camera_3d: Camera3D = $Player/Camera3D
@onready var chat_lines: RichTextLabel = $Control/VBoxContainer/ChatLines
@onready var mesh_instance_3d: MeshInstance3D = $"../MeshInstance3D"

@onready var root = get_tree().current_scene

@export var ip: String = "127.0.0.1"
@export var port: int = 25565
@export var username: String = "Player"

@onready var net = preload("res://Scripts/network.gd").new()

enum LoginState {
	OFFLINE = 0,
	HANDSHAKE,
	HANDSHAKE_SENT,
	LOGIN,
	LOGIN_SENT,
	POSITION,
	ONLINE
}

var timer := 0.0
var entityId : int = 0;
var worldSeed : int = 0;
var dimension : int = 0;
var loginState : LoginState = LoginState.OFFLINE;

func _ready():
	net.ConnectToHost(ip,port)
	loginState = LoginState.HANDSHAKE;

func _physics_process(_delta: float) -> void:
	HandlePackets()
	if (loginState != LoginState.ONLINE): return
	WritePositionLook();
	
func HandlePackets():	
	net.EnsureConnection();
	if (!net.Connected()): return;
	
	while(!net.Empty()):
		HandlePacket()

	# Fall back to this if we're still logging in
	match(loginState):
		LoginState.HANDSHAKE:
			WriteHandshake()
			loginState = LoginState.HANDSHAKE_SENT
		LoginState.LOGIN:
			WriteLogin()
			loginState = LoginState.LOGIN_SENT

func sanitize_text(s: String) -> String:
	var result := ""
	for c in s:
		var code := c.unicode_at(0)
		
		# Allow printable + newline + tab
		if code >= 32 or code == 9 or code == 10:
			result += c
	
	return result
	
func HandlePacket():
	var packetId = net.ReadByte();
	match(packetId):
		Enum.Packet.KEEP_ALIVE:
			pass
		Enum.Packet.LOGIN: # Login
			print("Got Login")
			entityId = net.ReadInteger();
			net.ReadString16()
			worldSeed = net.ReadLong();
			dimension = net.ReadByte();
			loginState = LoginState.ONLINE
			print("Logged in!")
		Enum.Packet.HANDSHAKE: # Handshake
			print("Got Handshake")
			net.ReadString16()
			loginState = LoginState.LOGIN
		Enum.Packet.SPAWN_POINT:
			print("Got Spawnpoint")
			player.spawn = Vector3i(
				net.ReadInteger(),
				net.ReadInteger(),
				net.ReadInteger()
			)
			print(player.spawn)
		Enum.Packet.TIME:
			root.UpdateTime(net.ReadLong())
		Enum.Packet.CHAT_MESSAGE:
			var text = sanitize_text(net.ReadString16());
			print(text)
			chat_lines.text = text
		Enum.Packet.SET_HEALTH:
			net.ReadShort()
		Enum.Packet.PLAYER_POSITION_LOOK:
			#print("Got Pos Look")
			var pos = Vector3.ZERO;
			var rot = Vector2.ZERO;
			pos.x = net.ReadDouble()
			pos.y = net.ReadDouble()
			net.ReadDouble()
			pos.z = net.ReadDouble()
			rot.x = net.ReadFloat()
			rot.y = net.ReadFloat()
			net.ReadBoolean()
			player.global_position = pos
			#print(rot)
			camera_3d.global_rotation_degrees.x = -rot.y
			player.global_rotation_degrees.y = -rot.x
		Enum.Packet.PRE_CHUNK:
			#print("Got Pre-Chunk")
			var cpos = Vector2i(net.ReadInteger(),net.ReadInteger())
			if (!net.ReadBoolean()):
				ClearChunk(cpos)
		Enum.Packet.CHUNK:
			#print("Got Chunk")
			var pos = Vector3i(net.ReadInteger(),net.ReadShort(),net.ReadInteger())
			var areaSize = Vector3i(net.ReadByte()+1,net.ReadByte()+1,net.ReadByte()+1)
			var chunkData = net.ReadChunkData(net.ReadInteger())
			DecompressChunk(pos,areaSize,chunkData)
		Enum.Packet.SPAWN_PLAYER_ENTITY:
			print("Spawn Player")
			var eid = net.ReadInteger()
			root.AddEntity(eid)
			# Get info
			var e = root.GetEntity(eid)
			var usr = net.ReadString16();
			var pos = Vector3i(net.ReadInteger(),net.ReadInteger(),net.ReadInteger());
			var look = Vector2i(net.ReadByte(),net.ReadByte());
			if (e):
				e.InitPlayer(eid,usr);
				e.BlockPosition(pos)
				e.Look(look)
			net.ReadShort()
		Enum.Packet.SPAWN_MOB_ENTITY:
			#print("Spawn Mob")
			var eid = net.ReadInteger()
			root.AddEntity(eid)
			var e = root.GetEntity(eid)
			var type = net.ReadByte()
			var pos = Vector3i(net.ReadInteger(), net.ReadInteger(), net.ReadInteger())
			var look = Vector2i(net.ReadByte(), net.ReadByte())
			if e:
				e.InitMob(eid, type)
				e.BlockPosition(pos / 32)
				e.Look(look)
				ReadMobMetadata(e) # pass entity to metadata reader
			else:
				ReadMobMetadata(null) # still consume metadata even if entity missing
		Enum.Packet.SPAWN_ITEM_ENTITY:
			print("Spawn Item")
			var eid = net.ReadInteger()
			root.AddEntity(eid)
			# Get info
			var e = root.GetEntity(eid)
			net.ReadShort()
			net.ReadByte()
			net.ReadShort()
			var pos = Vector3i(net.ReadInteger(),net.ReadInteger(),net.ReadInteger());
			var rot = Vector3i(net.ReadByte(),net.ReadByte(),net.ReadByte());
			if (e):
				e.BlockPosition(pos);
				e.Rotation(rot);
		Enum.Packet.ENTITY_EQUIPMENT:
			net.ReadInteger()
			net.ReadShort()
			net.ReadShort()
			net.ReadShort()
		Enum.Packet.ENTITY_POSITION_LOOK:
			var e = root.GetEntity(net.ReadInteger())
			var pos = Vector3i(net.ReadInteger(),net.ReadInteger(),net.ReadInteger());
			var look = Vector2i(net.ReadByte(),net.ReadByte());
			if (e):
				e.Position(pos)
				e.Look(look)
		Enum.Packet.ENTITY_HEALTH_ACTION:
			var e = root.GetEntity(net.ReadInteger())
			var action = net.ReadByte()
		Enum.Packet.DESTROY_ENTITY:
			root.RemoveEntity(net.ReadInteger())
		Enum.Packet.ENTITY_RELATIVE_POSITION:
			var e = root.GetEntity(net.ReadInteger())
			var pos = Vector3i(net.ReadByte(),net.ReadByte(),net.ReadByte());
			if (e):
				e.RelativePosition(pos)
		Enum.Packet.ENTITY_LOOK:
			var e = root.GetEntity(net.ReadInteger())
			var look = Vector2i(net.ReadByte(),net.ReadByte());
			if (e):
				e.Look(look)
		Enum.Packet.ENTITY_RELATIVE_POSITION_LOOK:
			var e = root.GetEntity(net.ReadInteger())
			var pos = Vector3i(net.ReadByte(),net.ReadByte(),net.ReadByte());
			var look = Vector2i(net.ReadByte(),net.ReadByte());
			if (e):
				e.RelativePosition(pos)
				e.Look(look)
		Enum.Packet.ENTITY_VELOCITY:
			var e = root.GetEntity(net.ReadInteger())
			var _pos = Vector3i(net.ReadShort(),net.ReadShort(),net.ReadShort());
			if (e):
				pass
		Enum.Packet.BLOCK_CHANGE:
			var pos = Vector3i(net.ReadInteger(),net.ReadByte(),net.ReadInteger())
			#print(pos)
			root.PlaceBlock(pos,net.ReadByte())
			net.ReadByte()
		Enum.Packet.PLAYER_ANIMATION:
			net.ReadInteger()
			net.ReadByte()
		Enum.Packet.EFFECT:
			net.ReadInteger()
			var _pos = Vector3i(net.ReadInteger(),net.ReadByte(),net.ReadInteger())
			net.ReadInteger()
		Enum.Packet.GAME_STATE:
			net.ReadByte()
		Enum.Packet.ENTITY_METADATA:
			var entity_id = net.ReadInteger()
			ReadMobMetadata()
		Enum.Packet.SET_INVENTORY_SLOT:
			#print("Set Inventory Slot")
			net.ReadByte()
			net.ReadShort()
			var itemId = net.ReadShort()
			if (itemId > -1):
				net.ReadByte()
				net.ReadShort()
		Enum.Packet.WINDOW_ITEMS:
			#print("Got Window Items")
			net.ReadByte()
			var payloadSize = net.ReadShort()
			for i in range(payloadSize):
				var itemId = net.ReadShort()
				if (itemId > -1):
					net.ReadByte()
					net.ReadShort()
			#print(payloadSize)
		Enum.Packet.SIGN:
			net.ReadInteger()
			net.ReadShort()
			net.ReadInteger()
			net.ReadString16()
			net.ReadString16()
			net.ReadString16()
			net.ReadString16()
		Enum.Packet.DISCONNET:
			print("Disconnected by Server!")
			print(net.ReadString16())
			loginState = LoginState.OFFLINE
			get_tree().quit()
		_:
			print("Unknown! (0x%X)" % packetId)
			get_tree().quit()

func WriteHandshake():
	net.WriteByte(Enum.Packet.HANDSHAKE)
	net.WriteString16(username)
	net.SendPacket()

func WriteLogin():
	net.WriteByte(Enum.Packet.LOGIN)
	net.WriteInteger(14);
	net.WriteString16(username);
	net.WriteLong(0);
	net.WriteByte(0);
	net.SendPacket()

func WritePositionLook():
	net.WriteByte(0x0D)
	net.WriteDouble(player.global_position.x)
	net.WriteDouble(player.global_position.y)
	net.WriteDouble(player.global_position.y+1.6)
	net.WriteDouble(player.global_position.z)
	net.WriteFloat(180.0-player.global_rotation_degrees.y)
	net.WriteFloat(-camera_3d.global_rotation_degrees.x)
	net.WriteBoolean(1)
	net.SendPacket()

func ReadMobMetadata(e = null):
	while true:
		var header = net.ReadByte()
		if header == 0x7F:
			break
		var type = header >> 5
		#print("Mob Type: " + str(type))
		var _index = header & 0x1F
		match type:
			0: # byte
				net.ReadByte()
			1: # short
				net.ReadShort()
			2: # int
				net.ReadInteger()
			3: # float
				net.ReadFloat()
			4: # string16
				net.ReadString16()
			5: # slot
				var item_id = net.ReadShort()
				if item_id != -1:
					net.ReadByte()
					net.ReadShort()
			6: # 3 ints
				net.ReadInteger()
				net.ReadInteger()
				net.ReadInteger()
			_:
				print("Unknown metadata type:", type)
				return

var chunks: Dictionary = {}  # Vector3i -> MeshInstance3D
var chunk_scene: PackedScene  # preload your MeshInstance3D scene

func DecompressChunk(pos: Vector3i, size: Vector3i, data: PackedByteArray) -> void:
	var expected_size = (size.x * size.y * size.z * 2.5)
	var decompressed = data.decompress_dynamic(expected_size, FileAccess.COMPRESSION_DEFLATE)
	
	# Get or create chunk instance
	var chunk: MeshInstance3D
	if chunks.has(pos):
		chunk = chunks[pos]
	else:
		chunk = preload("res://Scenes/chunk.tscn").instantiate()
		get_tree().current_scene.add_child(chunk)
		chunk.position = pos  # world position
		chunks[pos] = chunk
	
	chunk.generate_chunk_async(size, decompressed)

func RemoveChunk(pos: Vector3i) -> void:
	if chunks.has(pos):
		chunks[pos].queue_free()
		chunks.erase(pos)

func ClearChunk(cpos: Vector2i):
	var pos = Vector3i(cpos.x*16,0,cpos.y*16)
				#root.PlaceBlock(pos+off, -1)

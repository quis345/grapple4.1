extends Node2D

const team_colors = [Color(1, 0.5,0), Color(0, 0.5, 1)]
#var regen : Node
var main: Node2D
enum p {
	CONNECT,
	SYNC
}
var phase : p = p.CONNECT

var color : Color = Color(0,0,0)
var ball : RigidBody2D
var scoreboard : RichTextLabel
var scores := [0, 0]
var players = []
var countdown: float = -1.0

# big game changes
const SCALE = 2.0
const GRAVITY: bool = true
const SOCCAR_MODE: bool = false
const PADDLE_BALL: bool = true
const PRACTICE_MODE: bool = true
var time := 180.0

#soccar settings:
const hit_buffer := 30
const hit_power := 5.0
const NEAR_DAMP := 1.5
const DAMP_FALLOFF := 0.3
const BASE_DAMP := 0.00
const KICK_DELAY := 1.0

var max_time := 180.0
var winner = ""
var active := false

var ball_speed: int = 0

var multiplayer_peer = ENetMultiplayerPeer.new()
var connected_player_ids = []

var game_info : Array
# [game_port, max_players, mode, [[[player1peerid, player1user], player2], [player3, player4]], [scoreOrange, scoreBlue], time_left]


func reset():
	await get_tree().create_timer(0.0001).timeout
	winner = ""
	active = false
	time = max_time
	countdown = 5.0

func create_server():
	multiplayer_peer.create_server(game_info[0], game_info[1])
	multiplayer.multiplayer_peer = multiplayer_peer
	multiplayer_peer.peer_connected.connect(func(peer_id): add_peer(peer_id))
	
	multiplayer_peer.peer_disconnected.connect(func(peer_id): remove_peer(peer_id))

func add_peer(peer_id):
	connected_player_ids.append(peer_id)
	rpc_id(peer_id, "client_sync", SCALE, GRAVITY, SOCCAR_MODE, PADDLE_BALL, peer_id, multiplayer.get_unique_id())
	

func remove_peer(peer_id):
	connected_player_ids.erase(peer_id)


func _ready():
	var max_time = time
	countdown = 5.0
#	for player in players:
#		player.disabled = true
	main = self
	
	await get_tree().create_timer(0.001).timeout

func _process(delta):
	if phase == p.CONNECT:
		var passthru = true
		for team in game_info[3]:
			for player in team:
				if not player[2]:
					passthru = false
		
		if passthru:
			rpc("info_sync", game_info)
			phase = p.SYNC
	
	if ball != null and time <= 0:
		time = 0
		ball.disable = true
		for player in players: player[1].disabled = true
		if scores[0] > scores[1]:
			rpc("end_game", false)
		elif scores[1] > scores[0]:
			rpc("end_game", true)
		else:
			winner = "[center]DRAW!\nthis really should have a match point system but i havnt programed that yet lol"
			
		#main.get_node("transitionout").emitting = true
		await get_tree().create_timer(3.0).timeout
		players = []
		scores = [0, 0]
		get_tree().reload_current_scene()
		reset()
		
		if countdown <= 0 and countdown > -1:
			countdown = -1
			for player in players:
				player[1].disabled = false
			if GRAVITY:
				ball.gravity_scale = 1.0/SCALE
				ball.apply_impulse(Vector2(0, -1.2/pow(SCALE, 0.5)), Vector2.ZERO)
			active = true
		elif countdown > -1: 
			active = false
			countdown -= delta
			for player in players:
				if is_instance_valid(player[1]):
					player[1].disabled = true
			ball.gravity_scale = 0
			if GRAVITY:
				ball.position = Vector2(1920, 1620)
			else:
				ball.position = Vector2(1920, 1080)
			ball.linear_velocity = Vector2.ZERO
		if active: time -= delta

var pause = false
func _input(event):
	if event.is_action_pressed("debug"):
		if not pause: Engine.time_scale = 0
		else: Engine.time_scale = 1
		pause = not pause
	
@rpc("reliable", "call_remote", "authority")
func client_sync(sca,gra,soc,pad,p_id, a_id): pass

@rpc("reliable", "call_remote", "authority")
func info_sync(info): pass

@rpc("reliable", "call_remote", "any_peer")
func server_sync(peer_id, username):
	for team in game_info[3]:
		for player in team:
			if player[1] == username and not player[2]:
				game_info[3][game_info[3].find(team)][game_info[3][game_info[3].find(team)].find(player)][0] = peer_id
				game_info[3][game_info[3].find(team)][game_info[3][game_info[3].find(team)].find(player)][2] = true
				rpc_id(player[0], "set_team", int(team == game_info[3][1]))
				

extends SceneTree
## Loss and jitter are injected below ENet, including into its acknowledgements.

var listeners: Array[UDPServer] = []
var upstreams: Array[PacketPeerUDP] = []
var clients: Array = [null, null]
var pending: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var received: int = 0
var dropped: int = 0
var forwarded: int = 0
var _next_report: int = 0


func _initialize() -> void:
	random.seed = 82731
	for i: int in 2:
		var listener := UDPServer.new()
		if listener.listen(25434 + i, "127.0.0.1") != OK:
			push_error("PROXY_BIND_FAILED")
			quit(1)
			return
		listeners.append(listener)
		var upstream := PacketPeerUDP.new()
		upstream.connect_to_host("127.0.0.1", 25433)
		upstreams.append(upstream)
	print("PROXY_READY loss=0.10 delay_ms=50..100")


func _process(_delta: float) -> bool:
	for i: int in listeners.size():
		listeners[i].poll()
		if listeners[i].is_connection_available():
			clients[i] = listeners[i].take_connection()
		if clients[i] != null:
			_forward_available(clients[i], upstreams[i])
			_forward_available(upstreams[i], clients[i])
	var now: int = Time.get_ticks_msec()
	for i: int in range(pending.size() - 1, -1, -1):
		if pending[i].due <= now:
			pending[i].peer.put_packet(pending[i].packet)
			pending.remove_at(i)
			forwarded += 1
	if now >= _next_report:
		_next_report = now + 500
		var stats := FileAccess.open("res://.godot/network-fault/proxy-stats.json", FileAccess.WRITE)
		if stats:
			stats.store_string(JSON.stringify({"received": received, "dropped": dropped, "forwarded": forwarded}))
	if now > 85000:
		print("PROXY_RESULT received=%d dropped=%d forwarded=%d" % [received, dropped, forwarded])
		quit()
	return false


func _forward_available(source: PacketPeerUDP, target: PacketPeerUDP) -> void:
	while source.get_available_packet_count() > 0:
		var packet: PackedByteArray = source.get_packet()
		received += 1
		if random.randf() < 0.1:
			dropped += 1
			continue
		pending.append({"peer": target, "packet": packet, "due": Time.get_ticks_msec() + random.randi_range(50, 100)})

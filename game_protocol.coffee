class HexProtocol

  @CHANNEL = 'hex'

  constructor: (@handler, @send) ->
    @actions = []

  # parse received data and call the appropriate handler function
  receive: (type, data) ->
    switch type
      when 'load'
        [state] = data
        @handler._load(this, state)
      when 'sync'
        [steps, actions] = data
        @handler._sync(this, steps, actions)
      when 'playerStart'
        [@playerName] = data
        @handler._playerStart(this, @playerName)
      when 'attack'
        [gameData] = data
        @handler._attack(this, gameData)
      when 'chat'
        [message] = data
        @handler._chat(this, message)
      when 'playerJoined'
        [name, id, color] = data
        @handler._playerJoined(name, id, color)
      else
        console.log("ignored command [#{type}]")

  # sever -> client: initial game state
  load: (state) ->
    @send('load', [state])

  # sever -> client: incremental game updates
  sync: (steps) ->
    @send('sync', [steps, @actions])
    @actions = []
	
  # sever -> client: let other clients know of new player
  playerJoined: (name, id, color) ->
    @send('playerJoined', [name, id, color]);

  # client -> server: attempt player start
  playerStart: (@playerName) ->
    @send('playerStart', [@playerName])

  # client -> server: attempt player attack
  attack: (gameData) ->
    @send('attack', [gameData])

  # bidirectional: broadcast a chat message
  chat: (message) ->
    @send('chat', [message])

# public interface
(exports ? window).HexProtocol = HexProtocol

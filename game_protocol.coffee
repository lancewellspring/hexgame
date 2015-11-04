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
      when 'start'
        [@playerName] = data
        @handler._start(this, @playerName)
      when 'attack'
        [gameData] = data
        @handler._attack(this, gameData)
      when 'chat'
        [message] = data
        @handler._chat(this, message)
      else
        console.log("ignored command [#{type}]")

  # sever -> client: initial game state
  load: (state) ->
    @send('load', [state])

  # sever -> client: incremental game updates
  sync: (steps) ->
    @send('sync', [steps, @actions])
    @actions = []

  # client -> server: attempt player start
  start: (@playerName) ->
    @send('start', [@playerName])

  # client -> server: attempt player attack
  attack: (gameData) ->
    @send('attack', [gameData])

  # bidirectional: broadcast a chat message
  chat: (message) ->
    @send('chat', [message])

# public interface
(exports ? window).HexProtocol = HexProtocol

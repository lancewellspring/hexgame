class HexProtocol

  @CHANNEL = 'hex'

  constructor: (@handler, @send) ->

  # parse received data and call the appropriate handler function
  receive: (type, data) ->
    switch type
      when 'load'
        [state] = data
        @handler._load(state)
      when 'sync'
        [steps, actions] = data
        @handler._sync(steps, actions)
      when 'move'
        [gameData] = data
        @handler._move(gameData)
      when 'start'
        [playerName] = data
        @handler._start(playerName)
      when 'attack'
        [gameData] = data
        @handler._attack(gameData)
      else
        console.log("ignored command [#{type}]")

  # sever -> client: initial game state
  load: (state) ->
    @send('load', [state])

  # sever -> client: incremental game updates
  sync: (steps, actions) ->
    @send('sync', [steps, actions])

  # client -> server: attempt player move
  move: (gameData) ->
    @send('move', [gameData])
    
  # client -> server: attempt player start
  start: (gameData) ->
    @send('start', [gameData])
    
  # client -> server: attempt player attack
  attack: (gameData) ->
    @send('attack', [gameData])

# public interface
(exports ? window).HexProtocol = HexProtocol

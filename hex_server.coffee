HexVersion = require('./hex_version.js').HexVersion
HexCore = require('./hex_core.js').HexCore
HexPlayer = require('./hex_core.js').HexPlayer
HexProtocol = require('./hex_core.js').HexProtocol

# the game server code
class HexServer extends HexCore

  constructor: () ->
    super()
    @clients = []
    @actions = []

  update: (steps) ->
    super(steps)
    # apply *all* actions to the server's copy of the game
    @_sync(null, steps, @actions)
    @actions = []
    # send out subsets of actions to individual players
    for client in @clients
      client.sync(steps)

  addClient: (socket) ->
    send = (type, data) -> socket.emit(HexProtocol.CHANNEL, [type, data])
    protocol = new HexProtocol(this, send)
    @clients.push(protocol)
    console.log("#{@clients.length} connections")
    return protocol

  removeClient: (protocol) ->
    if protocol in @clients
      @clients.splice(@clients.indexOf(protocol), 1)
      if protocol.playerName?
        console.log("#{protocol.playerName} has left the game.")
    console.log("#{@clients.length} connections")

  _load: (protocol, state) ->
    console.log('a naughty client just sent the `load` command')

  _sync: (protocol, steps, actions) ->
    if protocol?
      console.log('a naughty client just sent the `sync` command')
    else
      super(protocol, steps, actions)

  _playerStart: (protocol, playerName) ->
    console.log("#{playerName} has joined the game!")
    #send all current players to new player
    for id, player of @players
      protocol.playerJoined(player.name, id, player.color)
    #give hex to player
    hex = @grid.getRandomStartingHex()
    player = new HexPlayer(playerName, null, null, protocol)
    @players[player.id] = player
    action = ['hex', player.id, hex.x, hex.y]
    @actions.push(action)
    protocol.actions.push(action)
    #immediately notify all clients of new player
    for client in @clients
      client.playerJoined(playerName, player.id, player.color)
    #show adjacent hexs to player
    hexs = @grid.getAdjacentHexs(hex)
    for h in hexs
      action = ['hex', hex?.owner?.id, h.x, h.y]
      protocol.actions.push(action)

  _attack: (protocol, gameData) ->
    [playerId, x, y] = gameData
    player = @players[playerId]
    hex = @grid.hexs[x][y]
    action = ['hex', playerId, hex.x, hex.y]
    @actions.push(action)
    protocol.actions.push(action)
    #show appropriate players the hex change.
    for id, p of @players
      if id == playerId
        continue
      if hex in p.hexs
        p.protocol.actions.push(['hex', playerId, hex.x, hex.y])
      else
        for h in p.hexs
          #TODO: there is likely a faster way to do this, not sure if its eating up much cpu tho.
          if hex in @grid.getAdjacentHexs(h)
            p.protocol.actions.push(['hex', playerId, hex.x, hex.y])
    #show adjacent hexs to player
    hexs = @grid.getAdjacentHexs(hex)
    for h in hexs
      #TODO: this often sends 'show' for hexs that the player can actually already see, improve performance?
      action = ['hex', h?.owner?.id, h.x, h.y]
      @actions.push(action)
      protocol.actions.push(action)

  _chat: (protocol, message) ->
    # ignore spoofed messages
    if not protocol.playerName?
      return
    # message formatting
    console.log("[chat] #{protocol.playerName}: #{message}")
    formatted = "<b>#{protocol.playerName}:</b> #{message}"
    # don't queue it with the other actions, relay it to everyone immediately
    for client in @clients
      client.chat(formatted)

(window ? {}).HexServer = exports.HexServer = HexServer

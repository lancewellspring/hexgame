{HexVersion} = require('./hex_version.js')
{HexCore} = require('./hex_core.js')
{HexPlayer} = require('./hex_core.js')
{HexProtocol} = require('./hex_core.js')

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
      # TODO: properly fix this error:
      #   TypeError: Cannot call method 'sync' of undefined
      #     at HexServer.update (/home/hex/common/app/public/hex_server.js:34:29)
      #     at null.<anonymous> (/home/hex/common/app/index.js:45:22)
      #     at wrapper [as _onTimeout] (timers.js:252:14)
      #     at Timer.listOnTimeout [as ontimeout] (timers.js:110:15)
      client?.sync(steps)

  addClient: (socket) ->
    send = (type, data) -> socket.emit(HexProtocol.CHANNEL, [type, data])
    protocol = new HexProtocol(this, send)
    @clients.push(protocol)
    console.log("#{@clients.length} connections")
    return protocol

  removeClient: (protocol) ->
    if protocol in @clients
      @clients.splice(@clients.indexOf(protocol), 1)
      if protocol.player?
        console.log("#{protocol.player.name} has left the game.")
        delete @players[protocol.player.id]
        for id, player of @players
          player.protocol.playerLeft(protocol.player.id)
        # TODO: remove this player's hex?

    console.log("#{@clients.length} connections")

  _load: (protocol, state) ->
    console.log('a naughty client just sent the `load` command')

  _sync: (protocol, steps, actions) ->
    if protocol?
      console.log('a naughty client just sent the `sync` command')
    else
      super(protocol, steps, actions)
      
  showPlayerAdjacentHexs: (player, protocol, hex) ->
    #TODO: this often sends 'show' for hexs that the player can actually already see, improve performance?
    hexs = @grid.getAdjacentHexs(hex)
    for h in hexs
      if h.owner != player
        action = ['hex', h?.owner?.id, h.x, h.y, h.units, h.stepCount]
        #@actions.push(action)
        protocol.actions.push(action)

  _playerStart: (protocol, playerName) ->
    console.log("#{playerName} has joined the game!")
    #send all current players to new player
    for id, player of @players
      protocol.playerJoined(player.name, id, player.color)
    #give hex to player
    hex = @grid.getRandomStartingHex()
    player = new HexPlayer(playerName, null, null, protocol)
    protocol.player = player
    @players[player.id] = player
    action = ['hex', player.id, hex.x, hex.y, 0, 0]
    @actions.push(action)
    protocol.actions.push(action)
    #immediately notify all clients of new player
    for client in @clients
      client.playerJoined(playerName, player.id, player.color)
    @showPlayerAdjacentHexs(player, protocol, hex)
      
  #update all players that can see the actions (including the sending player)
  updatePlayers: (fromHex, toHex, fromAction, toAction) ->
    for id, p of @players
      if fromHex in p.hexs
        p.protocol.actions.push(fromAction)
      if toHex in p.hexs
        p.protocol.actions.push(toAction)
      for h in p.hexs
        #TODO: there is likely a faster way to do this, not sure if its eating up much cpu tho.
        adjacent = @grid.getAdjacentHexs(h)
        if fromHex in adjacent
          p.protocol.actions.push(fromAction)
        if toHex in adjacent
          p.protocol.actions.push(toAction)
      
  #TODO: check if to and from are adjacent, and if so do the current logic for an instant move.  Otherwise, send the fromAction and a new action to kick off the unitSprite move, but set some kind of timer to send an updated toAction when the move should be complete (ie distance * rate).
  _moveUnits: (id, fromx, fromy, tox, toy, units) ->
    #update server with actions
    fromHex = @grid.hexs[fromx][fromy]
    fromAction = ['hex', id, fromx, fromy, fromHex.units-units, fromHex.stepCount]
    toHex = @grid.hexs[tox][toy]
    toAction = ['hex', id, tox, toy, toHex.units+units, toHex.stepCount]
    @actions.push(fromAction)
    @actions.push(toAction)
    console.log("(#{fromHex.x},#{fromHex.y},#{fromHex.units}) reinforcing (#{toHex.x},#{toHex.y},#{toHex.units})")
    @updatePlayers(fromHex, toHex, fromAction, toAction)

  _attack: (protocol, gameData) ->
    [playerId, fromx, fromy, tox, toy, units] = gameData
    player = @players[playerId]
    fromHex = @grid.hexs[fromx][fromy]
    toHex = @grid.hexs[tox][toy]
    fromAction = []
    toAction = []
    success = true
    console.log("(#{fromHex.x},#{fromHex.y},#{units}) attacking (#{toHex.x},#{toHex.y},#{toHex.units})")
    if units > toHex.units
      fromAction = ['hex', playerId, fromx, fromy, fromHex.units - units, fromHex.stepCount]
      toAction = ['hex', playerId, tox, toy, units-toHex.units, toHex.stepCount]
    else
      success = false
      fromAction = ['hex', playerId, fromx, fromy, fromHex.units - units, fromHex.stepCount]
      toAction = ['hex', toHex.owner, tox, toy, toHex.units-units, toHex.stepCount]
    @actions.push(fromAction)
    @actions.push(toAction)
    @updatePlayers(fromHex, toHex, fromAction, toAction)
    #show adjacent hexs to player
    if success
      @showPlayerAdjacentHexs(player, protocol, toHex)

  _chat: (protocol, message) ->
    # ignore spoofed messages
    if not protocol.player?
      return
    # message formatting
    console.log("[chat] #{protocol.player.name}: #{message}")
    formatted = "<b>#{protocol.player.name}:</b> #{message}"
    # don't queue it with the other actions, relay it to everyone immediately
    for client in @clients
      client.chat(formatted)

(window ? {}).HexServer = exports.HexServer = HexServer
